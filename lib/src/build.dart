import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:isolate_executor/isolate_executor.dart';
import 'package:runtime/runtime.dart';

import 'package:runtime/src/context.dart';

class BuildExecutable extends Executable<Null> {
  BuildExecutable(Map<String, dynamic> message) : super(message);

  String packageImportString;

  @override
  Future<Null> execute() async {
    final config = BuildContext(
        Uri.parse(message['sourceApplicationLibraryFileUri']),
        Uri.parse(message['outputDirectoryUri']),
        Uri.parse(message['productUri']),
        message['script']);
    final build = Build(config);
    await build.execute();
  }

  List<String> get imports =>
      ["package:runtime/runtime.dart", packageImportString];
}

class BuildManager {
  BuildManager(this.sourceApplicationLibraryFileUri, this.outputDirectoryUri,
      this.productUri) {
    final pubspecPath = sourceDirectoryUri
        .resolve("pubspec.yaml")
        .toFilePath(windows: Platform.isWindows);

    final contents = File(pubspecPath).readAsStringSync();
    final p = Pubspec.parse(contents);
    _packageName = p.name;
  }

  final Uri sourceApplicationLibraryFileUri;
  final Uri outputDirectoryUri;
  final Uri productUri;

  String get packageName => _packageName;

  String get libraryFileName =>
      sourceApplicationLibraryFileUri.pathSegments.last.split(".").first;

  Uri get sourceDirectoryUri => sourceApplicationLibraryFileUri.resolve("../");

  String _packageName;

  Future buildWithScript(String script) async {
    final exec = BuildExecutable({
      'sourceApplicationLibraryFileUri':
          sourceApplicationLibraryFileUri.toString(),
      'outputDirectoryUri': outputDirectoryUri.toString(),
      'script': script,
      'productUri': productUri.toString()
    })
      ..packageImportString = 'package:$packageName/$libraryFileName.dart';

    await IsolateExecutor.run(exec,
        packageConfigURI: sourceDirectoryUri.resolve(".packages"),
        imports: exec.imports,
        logHandler: (s) => print(s));
  }
}

class Build {
  Build(this.context);

  final BuildContext context;

  Map<String, Uri> get packageMap => _packageMap ??= context.resolvedPackages;
  Map<String, Uri> _packageMap;

  Future execute() async {
    print("Generating runtime...");
    final runtimeGenerator = context.context.generator;
    await runtimeGenerator.writeTo(context.buildRuntimeDirectory.uri);
    print("Generated runtime at '${context.buildRuntimeDirectory.uri}'.");

    print(
        "Copying application package (from '${context.sourceApplicationDirectory.uri}')...");
    copyPackage(context.sourceApplicationDirectory.uri,
        context.buildApplicationDirectory.uri);
    print(
        "Application packaged copied to '${context.buildApplicationDirectory.uri}'.");

    final pubspecMap =
        context._getPubspecMap(context.sourceApplicationDirectory.uri);
    final overrides = pubspecMap['dependency_overrides'];
    context.context.compilers.forEach((compiler) {
      final packageInfo = _getPackageInfoForCompiler(compiler);
      final sourceDirUri = packageInfo.uri;
      final targetDirUri =
          context.buildPackagesDirectory.uri.resolve("${packageInfo.name}/");

      print("Compiling package '${packageInfo.name}'...");
      copyPackage(sourceDirUri, targetDirUri);
      compiler.deflectPackage(Directory.fromUri(targetDirUri));
      overrides[packageInfo.name] = {
        "path": targetDirUri.toFilePath(windows: Platform.isWindows)
      };
      print("Package '${packageInfo.name} compiled to '${targetDirUri}'.");
    });

    print("Overriding application dependencies: $overrides...");
    File.fromUri(context.buildApplicationDirectory.uri.resolve("pubspec.yaml"))
        .writeAsStringSync(json.encode(pubspecMap));

    context
        ._getFile(context.buildApplicationDirectory.uri
            .resolve("bin/")
            .resolve("main.dart"))
        .writeAsStringSync(context.source);

    print("Fetching dependencies (--offline)...");
    await getDependencies();

    print("Compiling AOT build...");
    await compile(
        context.buildApplicationDirectory.uri
            .resolve("bin/")
            .resolve("main.dart"),
        context.executableUri);
    print("Success.");
  }

  Future getDependencies() async {
    final cmd = Platform.isWindows ? "pub.bat" : "pub";

    final res = await Process.run(cmd, ["get", "--offline"],
        workingDirectory: context.buildApplicationDirectory.uri
            .toFilePath(windows: Platform.isWindows),
        runInShell: true);
    if (res.exitCode != 0) {
      throw StateError(
          "'pub get' failed with the following message: ${res.stderr}");
    }
    print("${res.stdout}");
  }

  Future compile(Uri srcUri, Uri dstUri) async {
    final res = await Process.run(
        "dart2aot",
        [
          srcUri.toFilePath(windows: Platform.isWindows),
          dstUri.toFilePath(windows: Platform.isWindows)
        ],
        workingDirectory: context.buildApplicationDirectory.uri
            .toFilePath(windows: Platform.isWindows),
        runInShell: true);
    if (res.exitCode != 0) {
      throw StateError(
          "'pub get' failed with the following message: ${res.stderr}");
    }
    print("${res.stdout}");
  }

  void copyPackage(Uri srcUri, Uri dstUri) {
    copyDirectory(src: srcUri.resolve("lib/"), dst: dstUri.resolve("lib/"));
    context._getFile(srcUri.resolve("pubspec.yaml")).copy(
        dstUri.resolve("pubspec.yaml").toFilePath(windows: Platform.isWindows));
    context._getFile(srcUri.resolve("pubspec.lock")).copy(
        dstUri.resolve("pubspec.lock").toFilePath(windows: Platform.isWindows));
  }

  _PackageInfo _getPackageInfoForName(String packageName) {
    final packageUri = packageMap[packageName];
    if (packageUri == null) {
      throw StateError(
          'Package \'$packageName\' not found in package map. Make sure it is in dependencies and run \'pub get\'.');
    }

    return _PackageInfo(packageName, packageUri);
  }

  _PackageInfo _getPackageInfoForCompiler(Compiler compiler) {
    final compilerUri = reflect(compiler).type.location.sourceUri;
    final parser = RegExp("package\:([^\/]+)");
    final parsed = parser.firstMatch(compilerUri.toString());
    if (parsed == null) {
      throw StateError(
          "Could not identify package of Compiler '${compiler.runtimeType}' (from URI '${compilerUri}').");
    }

    final packageName = parsed.group(1);
    return _getPackageInfoForName(packageName);
  }
}

/// Configuration and context values used during [Build.execute].
class BuildContext {
  BuildContext(this.applicationLibraryFileUri, this.buildDirectoryUri,
      this.executableUri, this.source);

  /// A [Uri] to the library file of the application to be compiled.
  final Uri applicationLibraryFileUri;

  /// A [Uri] to the executable build product file.
  ///
  /// This file is executed by `dartaotruntime` CLI.
  final Uri executableUri;

  /// A [Uri] to directory where build artifacts are stored during the build process.
  final Uri buildDirectoryUri;

  /// The source script for the executable.
  final String source;

  /// The [RuntimeContext] available during the build process.
  MirrorContext get context => RuntimeContext.current as MirrorContext;

  /// The directory of the application being compiled.
  Directory get sourceApplicationDirectory =>
      _getDirectory(applicationLibraryFileUri.resolve("../"));

  /// The library file of the application being compiled.
  File get sourceLibraryFile => _getFile(applicationLibraryFileUri);

  /// The directory where build artifacts are stored.
  Directory get buildDirectory => _getDirectory(buildDirectoryUri);

  /// The generated runtime directory
  Directory get buildRuntimeDirectory =>
      _getDirectory(buildDirectoryUri.resolve("generated_runtime/"));

  /// Directory for compiled packages
  Directory get buildPackagesDirectory =>
      _getDirectory(buildDirectoryUri.resolve("packages/"));

  /// Directory for compiled application
  Directory get buildApplicationDirectory =>
      _getDirectory(buildDirectoryUri.resolve("application/"));

  /// Gets dependency package location relative to [sourceApplicationDirectory].
  Map<String, Uri> get resolvedPackages {
    return getResolvedPackageUris(
        sourceApplicationDirectory.uri.resolve(".packages"),
        relativeTo: sourceApplicationDirectory.uri);
  }

  /// Returns a [Directory] at [uri], creates it recursively if it doesn't exist.
  Directory _getDirectory(Uri uri) {
    final dir = Directory.fromUri(uri);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Returns a [File] at [uri], creates all parent directories recursively if necessary.
  File _getFile(Uri uri) {
    final file = File.fromUri(uri);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    return file;
  }

  /// Gets the pubspec file (as a map) from the directory at [projectUri].
  Map<String, dynamic> _getPubspecMap(Uri projectUri) {
    final pubpsecFile = File.fromUri(projectUri.resolve("pubspec.yaml"));
    final pubspec = Pubspec.parse(pubpsecFile.readAsStringSync());

    final pubspecMap = <String, dynamic>{};
    pubspecMap['name'] = pubspec.name;
    pubspecMap['version'] = pubspec.version.toString();
    pubspecMap['environment'] =
        pubspec.environment.map((k, v) => MapEntry(k, v.toString()));
    pubspecMap['dependencies'] = pubspec.dependencies
        .map((n, d) => MapEntry(n, _getDependencyAsMap(d, projectUri)));
    pubspecMap['dependency_overrides'] = pubspec.dependencyOverrides
        .map((n, d) => MapEntry(n, _getDependencyAsMap(d, projectUri)));
    return pubspecMap;
  }

  /// Returns a [Dependency] from a pubspec as a map or string.
  ///
  /// Path dependencies with relative paths are resolved against [baseUri].
  dynamic _getDependencyAsMap(Dependency dep, Uri baseUri) {
    if (dep is PathDependency) {
      final uri = Uri.parse(dep.path);
      final normalized = baseUri.resolveUri(uri).normalizePath();
      return {"path": normalized.path};
    } else if (dep is HostedDependency) {
      if (dep.hosted == null) {
        return "${dep.version}";
      } else {
        return {
          "hosted": {"name": dep.hosted.name, "url": dep.hosted.url}
        };
      }
    } else if (dep is GitDependency) {
      final m = {"git": <String, dynamic>{}};
      final inner = m["git"];

      if (dep.url != null) {
        inner["url"] = dep.url.toString();
      }

      if (dep.path != null) {
        inner["path"] = dep.path;
      }

      if (dep.ref != null) {
        inner["ref"] = dep.ref;
      }

      return m;
    }

    throw StateError('unexpected dependency type');
  }
}

class _PackageInfo {
  _PackageInfo(this.name, this.uri);

  final String name;
  final Uri uri;
}

library runtime;

import 'dart:io';

import 'package:runtime/src/compiler.dart';
import 'package:runtime/src/mirror_context.dart';

export 'package:runtime/src/analyzer.dart';
export 'package:runtime/src/context.dart';
export 'package:runtime/src/build.dart';
export 'package:runtime/src/compiler.dart';
export 'package:runtime/src/file_system.dart';
export 'package:runtime/src/generator.dart';
export 'package:runtime/src/build_context.dart';
export 'package:runtime/src/build_manager.dart';
export 'package:runtime/src/mirror_context.dart';
export 'package:runtime/src/exceptions.dart';
export 'package:runtime/src/mirror_coerce.dart';

/// Compiler for the runtime package itself.
///
/// Removes dart:mirror from a replica of this package, and adds
/// a generated runtime to the replica's pubspec.
class RuntimePackageCompiler extends Compiler {
  @override
  Map<String, dynamic> compile(MirrorContext context) => {};

  @override
  void deflectPackage(Directory destinationDirectory) {
    final libraryFile = File.fromUri(
        destinationDirectory.uri.resolve("lib/").resolve("runtime.dart"));
    libraryFile.writeAsStringSync(
        "library runtime;\nexport 'src/context.dart';\nexport 'src/exceptions.dart';");

    final contextFile = File.fromUri(destinationDirectory.uri
        .resolve("lib/")
        .resolve("src/")
        .resolve("context.dart"));
    final contextFileContents = contextFile.readAsStringSync().replaceFirst(
        "import 'package:runtime/src/mirror_context.dart' as context;",
        "import 'package:generated_runtime/generated_runtime.dart' as context;");
    contextFile.writeAsStringSync(contextFileContents);

    final pubspecFile =
        File.fromUri(destinationDirectory.uri.resolve("pubspec.yaml"));
    final pubspecContents = pubspecFile.readAsStringSync().replaceFirst(
        "\ndependencies:",
        "\ndependencies:\n  generated_runtime:\n    path: ../../generated_runtime/");
    pubspecFile.writeAsStringSync(pubspecContents);
  }
}

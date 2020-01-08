import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:isolate_executor/isolate_executor.dart';
import 'package:runtime/runtime.dart';

import 'build_context.dart';

class BuildExecutable extends Executable<Null> {
  BuildExecutable(Map<String, dynamic> message) : super(message) {
    context = BuildContext.fromMap(message);
  }

  BuildContext context;

  @override
  Future<Null> execute() async {
    final build = Build(context);
    await build.execute();
  }
}

class BuildManager {
  /// Creates a new build manager to compile a non-mirrored build.
  BuildManager(this.context);

  final BuildContext context;

  Uri get sourceDirectoryUri => context.sourceApplicationDirectory.uri;

  Future build() async {
    if (!context.buildDirectory.existsSync()) {
      context.buildDirectory.createSync();
    }

    // Here is where we need to provide a temporary copy of the script file with the main function stripped;
    // this is because when the RuntimeGenerator loads, it needs Mirror access to any declarations in this file

    // This file doesn't exist... and we really need to put it thru the analyzer to find the exact location of the main function
    // then write a copy of that file by snipping the main function completely.
    // then start the build executable and import that generated file
    // Uri has to be absolute
    final strippedScriptFile =
        File.fromUri(context.targetScriptFileWithoutMainFunctionUri)
          ..writeAsStringSync(context.source);

    final analyzer = CodeAnalyzer(strippedScriptFile.absolute.uri);
    final analyzerContext = analyzer.contexts.contextFor(analyzer.path);
    print((await analyzerContext.currentSession.getErrors(analyzer.path)).errors);
    final mainFunctions = analyzerContext.currentSession.getParsedUnit(analyzer.path).unit.declarations.whereType<FunctionDeclaration>().where((f) => f.name.name == "main").toList();

    var source = context.source;
    mainFunctions.reversed.forEach((f) {
      source = source.replaceRange(f.offset, f.end, "");
    });

    strippedScriptFile.writeAsStringSync(source);

    final exec = BuildExecutable(context.safeMap);

    await IsolateExecutor.run(exec,
        packageConfigURI: sourceDirectoryUri.resolve(".packages"),
        imports: [
          "package:runtime/runtime.dart",
          context.targetScriptFileWithoutMainFunctionUri.toString()
        ],
        logHandler: (s) => print(s));
  }

  Future clean() async {
    if (context.buildDirectory.existsSync()) {
      context.buildDirectory.deleteSync(recursive: true);
    }
  }
}

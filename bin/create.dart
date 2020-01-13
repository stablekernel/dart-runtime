import 'dart:io';

import 'package:args/args.dart';
import 'package:runtime/runtime.dart';

Future main(List<String> args) async {
  final parser = ArgParser();
  parser.addOption('library', abbr: "l", help: "Path to library file");
  parser.addOption('build-directory',
      abbr: "b",
      help:
          "Path to directory to store build artifacts (created by this script)", defaultsTo: "_build/");
  parser.addOption('output-file',
      abbr: "o", help: "Path to executable output of script", defaultsTo: 'runtime');
  parser.addOption('script',
      abbr: "s",
      help:
          "Path to the .dart script file to compile (contains a main function)", defaultsTo: "bin/main.dart");
  parser.addFlag('test',
      abbr: "t", help: "Include dev_dependencies when compiling, writes script as test");

  final results = parser.parse(args);

  final library = decode(results['library']);
  final buildDir = decode(results['build-directory']);
  final outputFile = decode(results['output-file']);
  final script = decode(results['script']);

  final ctx = BuildContext(
      library, buildDir, outputFile, File.fromUri(script).readAsStringSync(),
      forTests: results['test']);
  final bm = BuildManager(ctx);
  await bm.build();
}

Uri decode(String val) {
  final uri = Uri.parse(val);
  if (uri.isAbsolute) {
    return uri;
  }

  return Directory.current.uri.resolveUri(uri);
}

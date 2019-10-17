import 'dart:io';

import 'package:runtime/src/analyzer.dart';
import 'package:test/test.dart';
import 'package:command_line_agent/command_line_agent.dart';

void main() {
  test("ProjectAnalyzer can find a specific class declaration in project",
      () async {
    final terminal = ProjectAgent.existing(Directory.current.uri
        .resolve("test/")
        .resolve("test_packages/")
        .resolve("application/"));
    await terminal.getDependencies();

    var path = terminal.workingDirectory.absolute.uri;
    final p = CodeAnalyzer(path);
    final klass = p.getClassFromFile("ConsumerSubclass",
        terminal.libraryDirectory.absolute.uri.resolve("application.dart"));
    expect(klass, isNotNull);
    expect(klass.name.name, "ConsumerSubclass");
    expect(klass.extendsClause.superclass.name.name, "Consumer");
  });
}

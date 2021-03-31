import 'dart:io';

import 'package:runtime/runtime.dart';
import 'package:test/test.dart';

void main() {
  final absolutePathToAppLib = Directory.current.uri
      .resolve("test/")
      .resolve("test_packages/")
      .resolve("application/")
      .resolve("lib/")
      .toFilePath();
  late BuildContext ctx;

  setUpAll(() async {
    final cmd = Platform.isWindows ? "pub.bat" : "pub";

    final testPackagesUri =
        Directory.current.uri.resolve("test/").resolve("test_packages/");
    await Process.run(cmd, ["get", "--offline"],
        workingDirectory: testPackagesUri
            .resolve("application/")
            .toFilePath(windows: Platform.isWindows),
        runInShell: true);
    await Process.run(cmd, ["get", "--offline"],
        workingDirectory: testPackagesUri
            .resolve("dependency/")
            .toFilePath(windows: Platform.isWindows),
        runInShell: true);

    final appDir = Directory.current.uri
        .resolve("test/")
        .resolve("test_packages/")
        .resolve("application/");
    final appLib = appDir.resolve("lib/").resolve("application.dart");
    final tmp = Directory.current.uri.resolve("tmp/");
    ctx = BuildContext(
        appLib,
        tmp,
        tmp.resolve("app.aot"),
        File.fromUri(appDir.resolve("bin/").resolve("main.dart"))
            .readAsStringSync());
  });
  test("Get import directives using single quotes", () {
    final imports = ctx.getImportDirectives(
        source:
            "import 'package:foo.dart';\nimport 'package:bar.dart'; class Foobar {}");
    expect(
        imports, ["import 'package:foo.dart';", "import 'package:bar.dart';"]);
  });
  test("Get import directives using double quotes", () {
    final imports = ctx.getImportDirectives(
        source:
            "import \"package:foo/foo.dart\";\n import \"package:bar2/bar_.dart\"; class Foobar {}");
    expect(imports, [
      "import \"package:foo/foo.dart\";",
      "import \"package:bar2/bar_.dart\";"
    ]);
  });

  test("Find in file", () {
    final imports = ctx.getImportDirectives(
        uri: Directory.current.uri
            .resolve("test/")
            .resolve("test_packages/")
            .resolve("application/")
            .resolve("lib/")
            .resolve("application.dart"));
    expect(imports, [
      "import 'package:dependency/dependency.dart';",
      "import 'file:${absolutePathToAppLib}src/file.dart';"
    ]);
  });

  test("Resolve input URI and resolves import relative paths", () {
    final imports = ctx.getImportDirectives(
        uri: Uri.parse("package:application/application.dart"));
    expect(imports, [
      "import 'package:dependency/dependency.dart';",
      "import 'file:${absolutePathToAppLib}src/file.dart';"
    ]);
  });

  test("Resolve src files and parent directories", () {
    final imports = ctx.getImportDirectives(
        uri: Uri.parse("package:application/src/file.dart"));
    expect(imports, ["import 'file:${absolutePathToAppLib}application.dart';"]);
  });
}

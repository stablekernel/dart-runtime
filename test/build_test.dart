import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:runtime/runtime.dart';
import 'package:test/test.dart';

/*

Use both relative path and package path when exporting compiler from a dependecny package
to ensure both are caught by the auto-mechanism

// need to test for local (relative), in pub cache (absolute)
*/

void main() {
  // Need to create sample project, sample package that the project imports (that is configured to be runtimable)
  // project needs to use and subclass a type from sample package that needs a runtime
  // the project should be able to be executed to return a success message from compiled app that is 'different' than mirror app;
  // check that a bad project returns a bad exit code

  // need test with normal package, relative package, git package

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
    final bm = BuildManager(appLib, tmp, tmp.resolve("app.aot"));
    await bm.buildWithScript(
        File.fromUri(appDir.resolve("bin/").resolve("main.dart"))
            .readAsStringSync());
  });

  tearDownAll(() {
    Directory.fromUri(Directory.current.uri.resolve("tmp/"))
        .deleteSync(recursive: true);
  });

  test("Non-compiled version returns mirror runtimes", () async {
    final output = await dart(Directory.current.uri
        .resolve("test/")
        .resolve("test_packages/")
        .resolve("application/"));
    expect(json.decode(output),
        {"Consumer": "mirrored", "ConsumerSubclass": "mirrored"});
  });

  test(
      "Compiled version of application returns source generated runtimes and can be AOT compiled",
      () async {
    final output = await dartaotruntime(
        Directory.current.uri.resolve("tmp/").resolve("app.aot"),
        Directory.current.uri
            .resolve("test/")
            .resolve("test_packages/")
            .resolve("application/"));
    expect(json.decode(output),
        {"Consumer": "generated", "ConsumerSubclass": "generated"});
  });

  test("Accesses filesystem correctly w.r.t relative paths", () async {});
}

Future<String> dart(Uri appUri) async {
  final result = await Process.run("dart", ["bin/main.dart"],
      workingDirectory: appUri.toFilePath(windows: Platform.isWindows),
      runInShell: true);
  return result.stdout.toString();
}

Future<String> dartaotruntime(Uri buildUri, Uri appUri) async {
  final result = await Process.run(
      "dartaotruntime", [buildUri.toFilePath(windows: Platform.isWindows)],
      workingDirectory: appUri.toFilePath(windows: Platform.isWindows),
      runInShell: true);
  return result.stdout.toString();
}
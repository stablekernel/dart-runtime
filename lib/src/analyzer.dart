import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

class CodeAnalyzer {
  CodeAnalyzer(this.uri) {
    if (!uri.isAbsolute) {
      throw ArgumentError("'uri' must be absolute for CodeAnalyzer");
    }

    contexts = AnalysisContextCollection(includedPaths: [path]);

    if (contexts.contexts.isEmpty) {
      throw ArgumentError("no analysis context found for path '$path'");
    }
  }

  String get path {
    return getPath(uri);
  }

  late final Uri uri;

  late AnalysisContextCollection contexts;

  final _resolvedAsts = <String, ResolvedUnitResult>{};

  Future<ResolvedUnitResult> resolveUnitAt(Uri uri) async {
    for (final ctx in contexts.contexts) {
      final path = getPath(uri);
      if (_resolvedAsts.containsKey(path)) {
        return _resolvedAsts[path]!;
      }

      final output = await ctx.currentSession.getResolvedUnit(path);
      if (output.state == ResultState.VALID) {
        _resolvedAsts[path] = output;
        return output;
      }
    }

    throw ArgumentError("'uri' could not be resolved (contexts: "
        "${contexts.contexts.map((c) => c.contextRoot.root.toUri()).join(", ")})");
  }

  ClassDeclaration getClassFromFile(String className, Uri fileUri) {
    return _getFileAstRoot(fileUri)
        .declarations
        .whereType<ClassDeclaration>()
        .firstWhere((c) => c.name.name == className);
  }

  List<ClassDeclaration> getSubclassesFromFile(
      String superclassName, Uri fileUri) {
    return _getFileAstRoot(fileUri)
        .declarations
        .whereType<ClassDeclaration>()
        .where((c) => c.extendsClause!.superclass.name.name == superclassName)
        .toList();
  }

  CompilationUnit _getFileAstRoot(Uri fileUri) {
    final path = getPath(fileUri);
    if (_resolvedAsts.containsKey(path)) {
      return _resolvedAsts[path]!.unit!;
    }

    final unit = contexts.contextFor(path).currentSession.getParsedUnit(path);
    if (unit.errors.isNotEmpty) {
      throw StateError(
        "Project file '$path' could not be analysed for the "
        "following reasons:\n\t${unit.errors.join('\n\t')}",
      );
    }

    return unit.unit;
  }

  static String getPath(dynamic inputUri) {
    return PhysicalResourceProvider.INSTANCE.pathContext.normalize(
        PhysicalResourceProvider.INSTANCE.pathContext.fromUri(inputUri));
  }
}

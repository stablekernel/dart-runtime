import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

class CodeAnalyzer {
  CodeAnalyzer(this.uri) {
    if (!uri.isAbsolute) {
      throw ArgumentError("'uri' must be absolute for CodeAnalyzer");
    }

    contexts = AnalysisContextCollection(includedPaths: [path]);

    if (contexts.contexts.isEmpty) {
      throw ArgumentError("no analysis context found for path '${path}'");
    }
  }

  String get path {
    return _getPath(uri);
  }

  final Uri uri;

  AnalysisContextCollection contexts;

  ClassDeclaration getClassFromFile(String className, Uri fileUri) {
    return _getFileAstRoot(fileUri)
        .declarations
        .whereType<ClassDeclaration>()
        .firstWhere((c) => c.name.name == className, orElse: () => null);
  }

  List<ClassDeclaration> getSubclassesFromFile(
      String superclassName, Uri fileUri) {
    return _getFileAstRoot(fileUri)
        .declarations
        .whereType<ClassDeclaration>()
        .where((c) => c.extendsClause.superclass.name.name == superclassName)
        .toList();
  }

  CompilationUnit _getFileAstRoot(Uri fileUri) {
    final path = _getPath(fileUri);

    final unit = contexts.contextFor(path).currentSession.getParsedUnit(path);

    if (unit.errors.isNotEmpty) {
      throw StateError(
          "Project file '${path}' could not be analysed for the following reasons:\n\t${unit.errors.join("\n\t")}");
    }

    return unit.unit;
  }

  static String _getPath(dynamic inputUri) {
    return PhysicalResourceProvider.INSTANCE.pathContext.normalize(
        PhysicalResourceProvider.INSTANCE.pathContext.fromUri(inputUri));
  }

//  List<ClassDeclaration> getClassDeclarationsFromRoot(Uri uri) {
//    Map<Uri, List<ClassDeclaration>> fileToClassMap = {};
//    _scanUri(uri, fileToClassMap);
//    return fileToClassMap.values.expand((i) => i).toList();
//  }
//
//  void _scanUri(Uri uri, Map<Uri, List<ClassDeclaration>> fileToClassMap) {
//    print("Eval $uri");
//    if (fileToClassMap.containsKey(uri)) {
//      print("Already found");
//      return;
//    }
//
//    final fileAst = _getFileAstRoot(uri);
//    fileToClassMap[uri] = fileAst.declarations.whereType<ClassDeclaration>().toList();
//    print("Got AST with ${fileToClassMap[uri].length} classes.");
//
//    fileAst.directives
//      .whereType<Directive>()
//      .forEach((dir) {
//        var directiveUri;
//        if (dir is ExportDirective) {
//          directiveUri = dir.uri.stringValue;
//        } else if (dir is ImportDirective) {
//          directiveUri = dir.uri.stringValue;
//        }
//
//        if (directiveUri != null) {
//          _scanUri(_getPath(directiveUri), fileToClassMap);
//        }
//    });
//  }
}

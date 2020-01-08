import 'dart:mirrors';

import 'package:runtime/src/context.dart';
import 'package:runtime/src/compiler.dart';

RuntimeContext instance = MirrorContext._();

class MirrorContext extends RuntimeContext {
  MirrorContext._() {
    final m = <String, dynamic>{};
    compilers.forEach((c) {
      final compiledRuntimes = c.compile(this);
      if (m.keys.any((k) => compiledRuntimes.keys.contains(k))) {
        final matching = m.keys.where((k) => compiledRuntimes.keys.contains(k));
        throw StateError(
            'Could not compile. Type conflict for the following types: ${matching.join(", ")}.');
      }
      m.addAll(compiledRuntimes);
    });

    runtimes = RuntimeCollection(m);
  }

  final List<ClassMirror> types = currentMirrorSystem()
      .libraries
      .values
      .where((lib) => lib.uri.scheme == "package" || lib.uri.scheme == "file")
      .expand((lib) => lib.declarations.values)
      .whereType<ClassMirror>()
      .where((cm) => firstMetadataOfType<PreventCompilation>(cm) == null)
      .toList();

  List<Compiler> get compilers {
    return types
        .where((b) => b.isSubclassOf(reflectClass(Compiler)) && !b.isAbstract)
        .map((b) => b.newInstance(const Symbol(''), []).reflectee as Compiler)
        .toList();
  }

  List<ClassMirror> getSubclassesOf(Type type) {
    final mirror = reflectClass(type);
    return types.where((decl) {
      if (decl.isAbstract) {
        return false;
      }

      if (!decl.isSubclassOf(mirror)) {
        return false;
      }

      if (decl.hasReflectedType) {
        if (decl.reflectedType == type) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

T firstMetadataOfType<T>(DeclarationMirror dm, {TypeMirror dynamicType}) {
  final tMirror = dynamicType ?? reflectType(T);
  return dm.metadata
      .firstWhere((im) => im.type.isSubtypeOf(tMirror), orElse: () => null)
      ?.reflectee as T;
}

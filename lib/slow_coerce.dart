import 'package:runtime/src/exceptions.dart';

const String _listPrefix = "List<";
const String _mapPrefix = "Map<String,";

T? cast<T>(dynamic input) {
  try {
    var typeString = T.toString();
    if (typeString.endsWith('?')) {
      if (input == null) {
        return null;
      } else {
        typeString = typeString.substring(0, typeString.length - 1);
      }
    }
    if (typeString.startsWith(_listPrefix)) {
      if (input is! List) {
        throw TypeError();
      }

      if (typeString == "List<int>") {
        return List<int>.from(input) as T;
      } else if (typeString == "List<num>") {
        return List<num>.from(input) as T;
      } else if (typeString == "List<double>") {
        return List<double>.from(input) as T;
      } else if (typeString == "List<String>") {
        return List<String>.from(input) as T;
      } else if (typeString == "List<bool>") {
        return List<bool>.from(input) as T;
      } else if (typeString == "List<int?>") {
        return List<int?>.from(input) as T;
      } else if (typeString == "List<num?>") {
        return List<num?>.from(input) as T;
      } else if (typeString == "List<double?>") {
        return List<double?>.from(input) as T;
      } else if (typeString == "List<String?>") {
        return List<String?>.from(input) as T;
      } else if (typeString == "List<bool?>") {
        return List<bool?>.from(input) as T;
      } else if (typeString == "List<Map<String, dynamic>>") {
        final objects = <Map<String, dynamic>>[];
        input.forEach((o) {
          objects.add(o);
        });
        return objects as T;
      } else {
        final objects = <Map<String, dynamic>?>[];
        input.forEach((o) {
          if (o == null) {
            objects.add(null);
          } else {
            objects.add(o);
          }
        });
        return objects as T;
      }
    } else if (typeString.startsWith(_mapPrefix)) {
      if (input is! Map) {
        throw TypeError();
      }

      final inputMap = input as Map<String, dynamic>;
      if (typeString == "Map<String, int>") {
        return Map<String, int>.from(inputMap) as T;
      } else if (typeString == "Map<String, num>") {
        return Map<String, num>.from(inputMap) as T;
      } else if (typeString == "Map<String, double>") {
        return Map<String, double>.from(inputMap) as T;
      } else if (typeString == "Map<String, String>") {
        return Map<String, String>.from(inputMap) as T;
      } else if (typeString == "Map<String, bool>") {
        return Map<String, bool>.from(inputMap) as T;
      } else if (typeString == "Map<String, int>") {
        return Map<String, int?>.from(inputMap) as T;
      } else if (typeString == "Map<String, num>") {
        return Map<String, num?>.from(inputMap) as T;
      } else if (typeString == "Map<String, double>") {
        return Map<String, double?>.from(inputMap) as T;
      } else if (typeString == "Map<String, String>") {
        return Map<String, String?>.from(inputMap) as T;
      } else if (typeString == "Map<String, bool>") {
        return Map<String, bool?>.from(inputMap) as T;
      }
    }

    return input as T;
  } on TypeError {
    throw TypeCoercionException(T, input.runtimeType);
  }
}

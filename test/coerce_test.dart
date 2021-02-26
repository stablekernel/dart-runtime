import 'dart:convert';
import 'dart:mirrors';

import 'package:runtime/runtime.dart';
import 'package:runtime/src/mirror_coerce.dart';
import 'package:runtime/slow_coerce.dart';
import 'package:test/test.dart';

void main() {
  final mirrorCoerce = <T>(dynamic input) {
    return runtimeCast(input, reflectType(T)) as T;
  };

  final slowCoerce = <T>(dynamic input) {
    return cast<T>(input);
  };

  final testInvocation =
      (String suiteName, T? Function<T>(dynamic input) coerce) {
    group("($suiteName) Primitive Types (success)", () {
      test("dynamic", () {
        final x = coerce<dynamic>(wash("foo"));
        expect(x, "foo");
        expect(coerce<dynamic>(null), null);
      });
      test("int", () {
        final x = coerce<int>(wash(2));
        expect(x, 2);

        expect(coerce<int?>(null), null);
      });
      test("String", () {
        final x = coerce<String>(wash("string"));
        expect(x, "string");
        expect(coerce<String?>(null), null);
      });
      test("bool", () {
        final x = coerce<bool>(wash(true));
        expect(x, true);
        expect(coerce<bool?>(null), null);
      });
      test("num", () {
        final x = coerce<num>(wash(3.2));
        expect(x, 3.2);
        expect(coerce<num?>(null), null);

        final y = coerce<int>(wash(3));
        expect(y, 3);
      });
      test("double", () {
        final x = coerce<double>(wash(3.2));
        expect(x, 3.2);
        expect(coerce<double?>(null), null);
      });
    });

    group("($suiteName) Primitive Types (cast error)", () {
      test("int fail", () {
        try {
          coerce<int>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, int);
          expect(e.actualType, String);
        }
      });
      test("String fail", () {
        try {
          coerce<String>(wash(5));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, String);
          expect(e.actualType, int);
        }
      });
      test("bool fail", () {
        try {
          coerce<bool>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, bool);
          expect(e.actualType, String);
        }
      });
      test("num fail", () {
        try {
          coerce<num>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, num);
          expect(e.actualType, String);
        }
      });
      test("double fail", () {
        try {
          coerce<double>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, double);
          expect(e.actualType, String);
        }
      });
    });

    group("($suiteName) List Types (success)", () {
      test("null/empty", () {
        List<String>? x = coerce<List<String>?>(null);
        expect(x, null);

        x = coerce<List<String>>([])!;
        expect(x, []);
      });

      test("int", () {
        List<int> x = coerce<List<int>>(wash([2, 4]))!;
        expect(x, [2, 4]);
      });

      test("String", () {
        List<String> x = coerce<List<String>>(wash(["a", "b", "c"]))!;
        expect(x, ["a", "b", "c"]);
      });

      test("num", () {
        List<num> x = coerce<List<num>>(wash([3.0, 2]))!;
        expect(x, [3.0, 2]);
      });

      test("bool", () {
        List<bool> x = coerce<List<bool>>(wash([false, true]))!;
        expect(x, [false, true]);
      });

      test("list of map", () {
        List<Map<String, dynamic>?> x =
            coerce<List<Map<String, dynamic>?>>(wash([
          {"a": "b"},
          null,
          {"a": 1}
        ]))!;
        expect(x, [
          {"a": "b"},
          null,
          {"a": 1}
        ]);

        expect(coerce<List<Map<String, dynamic>>?>(null), null);
        expect(
            coerce<List<Map<String, dynamic>>>([]), <Map<String, dynamic>>[]);
      });
    });

    group("($suiteName) List Types (cast error)", () {
      test("heterogenous", () {
        try {
          coerce<List<int>>(wash(["x", 4]));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "List<int>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });

      test("homogenous, wrong type", () {
        try {
          cast<List<String>>(wash([4]));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "List<String>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });

      test("outer list ok, inner list not ok", () {
        try {
          coerce<List<List<String>>>(wash([
            ["foo", 3],
            ["baz"]
          ]));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "List<List<String>>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });

      test("list of map, inner map not ok", () {
        try {
          coerce<List<Map<String, int>>>(wash([
            {"a": 1},
            {"a": "b"}
          ]));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "List<Map<String, int>>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });
    });

    group("($suiteName) Map types (success)", () {
      test("null", () {
        Map<String, dynamic>? x = coerce<Map<String, dynamic>?>(null);
        expect(x, null);
      });

      test("string->dynamic", () {
        Map<String, dynamic> x =
            coerce<Map<String, dynamic>>(wash({"a": 1, "b": "c"}))!;
        expect(x, {"a": 1, "b": "c"});
      });

      test("string->int", () {
        Map<String, int> x = coerce<Map<String, int>>(wash({"a": 1, "b": 2}))!;
        expect(x, {"a": 1, "b": 2});
      });

      test("string->num", () {
        Map<String, num> x =
            coerce<Map<String, num>>(wash({"a": 1, "b": 2.0}))!;
        expect(x, {"a": 1, "b": 2.0});
      });

      test("string->string", () {
        Map<String, String> x =
            coerce<Map<String, String>>(wash({"a": "1", "b": "2.0"}))!;
        expect(x, {"a": "1", "b": "2.0"});
      });
    });

    group("($suiteName) Map types (failure)", () {
      test("bad key type", () {
        try {
          // Note: this input is not 'washed' as the wash function encodes/decodes via json, and this would be invalid json
          // But for the purpose of this test, we want an untyped map, which this input is
          coerce<Map<String, dynamic>>(<dynamic, dynamic>{"a": 1, 2: "c"});
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "Map<String, dynamic>");
          expect(e.actualType.toString(), endsWith("Map<dynamic, dynamic>"));
        }
      });

      test("bad val type", () {
        try {
          coerce<Map<String, int>>(wash({"a": 1, "b": "foo"}));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "Map<String, int>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }
      });

      test("nested list has invalid element", () {
        try {
          coerce<Map<String, List<String>>>(wash({
            "a": [2]
          }));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "Map<String, List<String>>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }
      });

      test("nested map has invalid value type", () {
        try {
          coerce<Map<String, Map<String, int>>>(wash({"a": []}));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "Map<String, Map<String, int>>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }

        try {
          coerce<Map<String, Map<String, int>>>(wash({
            "a": {"b": "foo"}
          }));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType.toString(), "Map<String, Map<String, int>>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }
      });
    });
  };

  testInvocation("mirrored", mirrorCoerce);
  testInvocation("stringified", slowCoerce);
}

dynamic wash(dynamic input) {
  return json.decode(json.encode(input));
}

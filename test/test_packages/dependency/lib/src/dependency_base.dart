import 'package:runtime/runtime.dart';


class Consumer {
  String get message => (RuntimeContext.current[runtimeType] as ConsumerRuntime).message;
}

abstract class ConsumerRuntime {
  String get message;
}
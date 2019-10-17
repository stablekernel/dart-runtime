import 'dart:convert';

import 'package:application/application.dart';
import 'package:dependency/dependency.dart';

void main() {
  print("${json.encode({
    "Consumer": Consumer().message,
    "ConsumerSubclass": ConsumerSubclass().message
  })}");
}

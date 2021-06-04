import 'package:macro_builder/src/json.dart';

@toJson
class User {
  final String name;

  User({required this.name});

  external Map<String, Object?> toJson();
}

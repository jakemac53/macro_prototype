import 'package:macro_builder/src/json.dart';
import 'package:macro_builder/src/observable.dart';

@toJson
class User {
  @observable
  String name;

  User({required this.name});

  external Map<String, Object?> toJson();
}

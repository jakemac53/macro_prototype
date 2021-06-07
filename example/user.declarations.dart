import 'package:macro_builder/src/json.dart';
import 'package:macro_builder/src/observable.dart';

@toJson
class User {
  @observable
  external String? name;
  external Map<String, Object?> toJson();
  User({String? name}) {
    this.name = name;
  }
}

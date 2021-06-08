import 'macros/json.dart';
import 'macros/observable.dart';

@toJson
class User {
  @observable
  external String? name;
  external Map<String, Object?> toJson();
  User({String? name}) {
    this.name = name;
  }
}

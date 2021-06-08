import 'macros/json.dart';
import 'macros/observable.dart';

@toJson
class User {
  external Map<String, Object?> toJson();
  @observable
  external String? name;
  User({String? name}) {
    this.name = name;
  }
}

@toJson
class Group {
  external Map<String, Object?> toJson();
  final String name;
  final List<User> users;
  Group({this.name = '', this.users = const []});
}

import 'macros/json.dart';
import 'macros/observable.dart';

@toJson
class User {
  @observable
  external String? name;
  User({String? name}) {
    this.name = name;
  }
}

@toJson
class Group {
  final String name;
  final List<User> users;
  Group({this.name = '', this.users = const []});
}

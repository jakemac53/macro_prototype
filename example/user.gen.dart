import 'macros/json.dart';
import 'macros/observable.dart';

@toJson
class User {
  @observable
  external String name;

  User(String name) {
    // TODO: ugly - can't used field initializing formals etc
    this.name = name;
  }
}

@toJson
class Group {
  final String name;
  final List<User> users;

  Group(this.name, this.users);
}

@toJson
class Manager extends User {
  final List<User> reports;

  Manager(String name, this.reports) : super(name);
}

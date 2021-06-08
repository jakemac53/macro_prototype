import 'macros/json.dart';

@jsonSerializable
class User {
  String name;

  User(this.name);
}

@jsonSerializable
class Group {
  final String name;
  final List<User> users;

  Group(this.name, this.users);
}

@jsonSerializable
class Manager extends User {
  final List<User> reports;

  Manager(String name, this.reports) : super(name);
}

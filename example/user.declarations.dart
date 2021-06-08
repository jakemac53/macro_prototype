import 'macros/json.dart';

@jsonSerializable
class User {
  external Map<String, Object?> toJson();
  external User.fromJson(Map<String, Object?> json);
  String name;
  User(this.name);
}

@jsonSerializable
class Group {
  external Map<String, Object?> toJson();
  external Group.fromJson(Map<String, Object?> json);
  final String name;
  final List<User> users;
  Group(this.name, this.users);
}

@jsonSerializable
class Manager extends User {
  external Map<String, Object?> toJson();
  external Manager.fromJson(Map<String, Object?> json);
  final List<User> reports;
  Manager(String name, this.reports) : super(name);
}

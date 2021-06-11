import 'macros/data_class.dart';
import 'macros/json.dart';

@dataClass
@jsonSerializable
class User {
  @jsonSerializable
  external Map<String, Object?> toJson();
  @jsonSerializable
  external User.fromJson(Map<String, Object?> json);
  User({
    required this.name,
  });
  String name;
}

@dataClass
@jsonSerializable
class Group {
  @jsonSerializable
  external Map<String, Object?> toJson();
  @jsonSerializable
  external Group.fromJson(Map<String, Object?> json);
  Group({
    required this.name,
    required this.users,
  });
  final String name;
  final List<User> users;
}

@jsonSerializable
class Manager extends User {
  @jsonSerializable
  external Map<String, Object?> toJson();
  @jsonSerializable
  external Manager.fromJson(Map<String, Object?> json);
  final List<User> reports;
  Manager({required String name, required this.reports}) : super(name: name);
}

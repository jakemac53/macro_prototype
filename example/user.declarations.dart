import 'macros/data_class.dart';
import 'macros/json.dart';

@dataClass
@jsonSerializable
class User {
  external Map<String, Object?> toJson();
  external User.fromJson(Map<String, Object?> json);
  User({
    required this.name,
  });
  String name;
}

@dataClass
@jsonSerializable
class Group {
  external Map<String, Object?> toJson();
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
  external Map<String, Object?> toJson();
  external Manager.fromJson(Map<String, Object?> json);
  final List<User> reports;
}

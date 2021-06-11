import 'macros/data_class.dart';
import 'macros/json.dart';

@dataClass
@jsonSerializable
class User {
  String name;
  @jsonSerializable
  Map<String, Object?> toJson() => <String, Object?>{
        "name": name,
      };

  @jsonSerializable
  User.fromJson(
    Map<String, Object?> json,
  ) : name = json["name"] as String;

  User({required this.name});
}

@dataClass
@jsonSerializable
class Group {
  final String name;
  final List<User> users;
  @jsonSerializable
  Map<String, Object?> toJson() => <String, Object?>{
        "name": name,
        "users": [for (var e in users) e],
      };

  @jsonSerializable
  Group.fromJson(
    Map<String, Object?> json,
  )   : name = json["name"] as String,
        users = [for (var e in json["users"] as List<Object?>) e as User];

  Group({required this.name, required this.users});
}

@jsonSerializable
class Manager extends User {
  final List<User> reports;
  @jsonSerializable
  Map<String, Object?> toJson() => <String, Object?>{
        "reports": [for (var e in reports) e],
        "name": name,
      };

  @jsonSerializable
  Manager.fromJson(
    Map<String, Object?> json,
  )   : reports = [for (var e in json["reports"] as List<Object?>) e as User],
        super.fromJson(json);

  Manager({required String name, required this.reports}) : super(name: name);
}

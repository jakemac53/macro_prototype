import 'macros/data_class.dart';
import 'macros/json.dart';

@dataClass
@jsonSerializable
class User {
  User.fromJson(
    Map<String, Object?> json,
  ) : name = json["name"] as String;
  Map<String, Object?> toJson() => <String, Object?>{
        "name": name,
      };
  String name;
  User({this.name});
}

@dataClass
@jsonSerializable
class Group {
  Group.fromJson(
    Map<String, Object?> json,
  )   : name = json["name"] as String,
        users = [
          for (var e in json["users"] as List<Object?>)
            User.fromJson(e as Map<String, Object?>)
        ];
  Map<String, Object?> toJson() => <String, Object?>{
        "name": name,
        "users": [for (var e in users) e.toJson()],
      };
  final String name;
  final List<User> users;
  Group({this.name, this.users});
}

@jsonSerializable
class Manager extends User {
  Manager.fromJson(
    Map<String, Object?> json,
  )   : reports = [
          for (var e in json["reports"] as List<Object?>)
            User.fromJson(e as Map<String, Object?>)
        ],
        super.fromJson(json);
  Map<String, Object?> toJson() => <String, Object?>{
        "reports": [for (var e in reports) e.toJson()],
        "name": name,
      };
  final List<User> reports;
}

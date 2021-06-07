import 'package:macro_builder/src/json.dart';
import 'package:macro_builder/src/observable.dart';

@toJson
class User {
  Map<String, Object?> toJson() => <String, Object?>{
        "name": name,
      };
  String? get name => _name;
  void set name(String? val) {
    print('Setting name to ${val}');
    _name = val;
  }

  String? _name;

  User({String? name}) {
    this.name = name;
  }
}

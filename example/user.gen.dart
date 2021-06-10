import 'macros/data_class.dart';
import 'macros/json.dart';

@dataClass
@jsonSerializable
class User {
  String name;
}

@dataClass
@jsonSerializable
class Group {
  final String name;
  final List<User> users;
}

// @dataClass
@jsonSerializable
class Manager extends User {
  final List<User> reports;
}

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

@jsonSerializable
class Manager extends User {
  final List<User> reports;
  Manager({required String name, required this.reports}) : super(name: name);
}

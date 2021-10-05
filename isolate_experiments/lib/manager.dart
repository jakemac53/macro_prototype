import 'package:macro_builder/macros/data_class.dart';
import 'package:macro_builder/macros/json.dart';

import 'user.dart';

@dataClass
@jsonSerializable
class Manager extends User {
  final List<User> reports;
}

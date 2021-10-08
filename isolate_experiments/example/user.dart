import 'package:macro_builder/macros/data_class.dart';
import 'package:macro_builder/macros/json.dart';

@dataClass
@jsonSerializable
class User {
  String name;
}

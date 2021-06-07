import 'package:collection/collection.dart';

import '../code.dart';
import '../macro.dart';

const toJson = JsonMacro();

class JsonMacro implements ClassDefinitionMacro {
  const JsonMacro();

  void define(TargetClassDefinition definition) {
    var toJsonMethod =
        definition.methods.firstWhereOrNull((m) => m.name == 'toJson');
    if (toJsonMethod == null) {
      throw 'No toJson method found on class ${definition.name}';
    }
    var code = Code('=> <String, Object?>{\n');
    for (var field in definition.fields) {
      code = Code('$code  "${field.name}": ${field.name},\n');
    }
    code = Code('$code};');
    toJsonMethod.implement(code);
    print('\n$code');
  }
}

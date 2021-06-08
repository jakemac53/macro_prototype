import 'package:macro_builder/macro_builder.dart';

const observable = ObservableMacro();

class ObservableMacro implements FieldDefinitionMacro {
  const ObservableMacro();

  void define(TargetFieldDefinition definition) {
    var backingFieldName = ' _${definition.name}';
    var backingField =
        Code('late ${definition.type.toCode()} $backingFieldName;');
    var getter = Code('${definition.type.toCode()} get ${definition.name} => '
        '$backingFieldName;');
    var setter = Code('''
void set ${definition.name}(${definition.type.toCode()} val) {
  print('Setting ${definition.name} to \${val}');
  $backingFieldName = val;
}''');
    definition.withGetterSetterPair(getter, setter,
        supportingDeclarations: [backingField]);
  }
}

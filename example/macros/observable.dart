import 'package:macro_builder/macro_builder.dart';

const observable = ObservableMacro();

class ObservableMacro implements FieldDeclarationMacro {
  const ObservableMacro();

  void visitFieldDeclaration(
      FieldDeclaration definition, ClassDeclarationBuilder builder) {
    if (!definition.name.startsWith('_')) {
      throw ArgumentError(
          '@observable can only annotate private fields, and it will create '
          'public getters and setters for them, but the public field '
          '${definition.name} was annotated.');
    }
    var publicName = definition.name.substring(1);
    var getter = Fragment('${definition.type.toCode()} get $publicName => '
        '${definition.name};');
    builder.addToClass(getter);

    var setter = Fragment('''
void set $publicName(${definition.type.toCode()} val) {
  print('Setting $publicName to \${val}');
  ${definition.name} = val;
}''');
    builder.addToClass(setter);
  }
}

import 'package:macro_builder/macro_builder.dart';

const observable = ObservableMacro();

class ObservableMacro implements FieldDeclarationMacro, ClassDeclarationMacro {
  const ObservableMacro();

  void forClassDeclaration(TargetClassDeclaration declaration) {
    for (var field in declaration.fields) {
      forFieldDeclaration(field);
    }
  }

  void forFieldDeclaration(TargetFieldDeclaration declaration) {
    if (!declaration.name.startsWith('_')) {
      throw ArgumentError(
          '@observable can only annotate private fields, and it will create '
          'public getters and setters for them, but the public field '
          '${declaration.name} was annotated.');
    }
    var publicName = declaration.name.substring(1);
    var getter = Code('${declaration.type.toCode()} get $publicName => '
        '${declaration.name};');
    declaration.addToClass(getter);

    var setter = Code('''
void set $publicName(${declaration.type.toCode()} val) {
  print('Setting $publicName to \${val}');
  ${declaration.name} = val;
}''');
    declaration.addToClass(setter);
  }
}

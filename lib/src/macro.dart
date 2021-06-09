import 'declarations.dart';
import 'definitions.dart';
import 'types.dart';

abstract class Macro {}

abstract class TypeMacro implements Macro {}

abstract class DeclarationMacro implements Macro {}

abstract class DefinitionMacro implements Macro {}

abstract class ClassTypeMacro implements TypeMacro {
  void forClassType(TargetClassType type);
}

abstract class ClassDeclarationMacro implements DeclarationMacro {
  void forClassDeclaration(TargetClassDeclaration declaration);
}

abstract class ClassDefinitionMacro implements DefinitionMacro {
  void forClassDefinition(TargetClassDefinition definition);
}

abstract class FieldTypeMacro implements TypeMacro {
  void forFieldType(TargetFieldType type);
}

abstract class FieldDeclarationMacro implements DeclarationMacro {
  void forFieldDeclaration(TargetFieldDeclaration declaration);
}

abstract class FieldDefinitionMacro implements DefinitionMacro {
  void forFieldDefinition(TargetFieldDefinition definition);
}

abstract class MethodTypeMacro implements TypeMacro {
  void forMethodType(TargetMethodType type);
}

abstract class MethodDeclarationMacro implements DeclarationMacro {
  void forMethodDeclaration(TargetMethodDeclaration declaration);
}

abstract class MethodDefinitionMacro implements DefinitionMacro {
  void forMethodDefinition(TargetMethodDefinition definition);
}

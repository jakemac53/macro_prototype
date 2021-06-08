import 'declarations.dart';
import 'definitions.dart';
import 'types.dart';

abstract class Macro {}

abstract class TypeMacro implements Macro {}

abstract class DeclarationMacro implements Macro {}

abstract class DefinitionMacro implements Macro {}

abstract class ClassTypeMacro implements TypeMacro {
  void type(TargetClassType type);
}

abstract class ClassDeclarationMacro implements DeclarationMacro {
  void declare(TargetClassDeclaration declaration);
}

abstract class ClassDefinitionMacro implements DefinitionMacro {
  void define(TargetClassDefinition definition);
}

abstract class FieldTypeMacro implements TypeMacro {
  void type(TargetFieldType type);
}

abstract class FieldDeclarationMacro implements DeclarationMacro {
  void declare(TargetFieldDeclaration declaration);
}

abstract class FieldDefinitionMacro implements DefinitionMacro {
  void define(TargetFieldDefinition definition);
}

abstract class MethodTypeMacro implements TypeMacro {
  void type(TargetMethodType type);
}

abstract class MethodDeclarationMacro implements DeclarationMacro {
  void declare(TargetMethodDeclaration declaration);
}

abstract class MethodDefinitionMacro implements DefinitionMacro {
  void define(TargetMethodDefinition definition);
}

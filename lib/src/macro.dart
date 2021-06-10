import 'declarations.dart';
import 'definitions.dart';
import 'types.dart';

abstract class Macro {}

abstract class ClassTypeMacro implements TypeMacro {
  void type(ClassType type, TypeBuilder builder);
}

abstract class ClassDeclarationMacro implements DeclarationMacro {
  void declare(ClassDeclaration declaration, ClassDeclarationBuilder builder);
}

// This isn't needed. Instead, a class-level macro that adds members
// must implement FieldDefinitionMacro and/or MethodDefinitionMacro and then
// has those invoked directly for the members it has declared.
//
// A macro that declares a member is committing itself to defining it later.
// abstract class ClassDefinitionMacro implements DefinitionMacro {
//   void define(TargetClassDefinition definition);
// }

abstract class FieldTypeMacro implements TypeMacro {
  void type(FieldType type, TypeBuilder builder);
}

abstract class FieldDeclarationMacro implements DeclarationMacro {
  void declare(FieldDeclaration declaration, ClassDeclarationBuilder builder);
}

abstract class FieldDefinitionMacro implements DefinitionMacro {
  void define(FieldDefinition definition, FieldDefinitionBuilder builder);
}

abstract class MethodTypeMacro implements TypeMacro {
  void type(MethodType type, TypeBuilder builder);
}

abstract class MethodDeclarationMacro implements DeclarationMacro {
  void declare(MethodDeclaration declaration, ClassDeclarationBuilder builder);
}

abstract class MethodDefinitionMacro implements DefinitionMacro {
  void define(MethodDefinition definition MethodDefinitionBuilder builder);
}

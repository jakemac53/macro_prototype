import 'declarations.dart';
import 'definitions.dart';
import 'types.dart';

abstract class Macro {}

abstract class TypeMacro implements Macro {}

abstract class DeclarationMacro implements Macro {}

abstract class DefinitionMacro implements Macro {}

abstract class ClassTypeMacro implements TypeMacro {
  void visitClassType(ClassType type, TypeBuilder builder);
}

abstract class ClassDeclarationMacro implements DeclarationMacro {
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder);
}

abstract class FieldTypeMacro implements TypeMacro {
  void visitFieldType(FieldType type, TypeBuilder builder);
}

abstract class FieldDeclarationMacro implements DeclarationMacro {
  void visitFieldDeclaration(
      FieldDeclaration declaration, ClassDeclarationBuilder builder);
}

abstract class FieldDefinitionMacro implements DefinitionMacro {
  void visitFieldDefinition(
      FieldDefinition definition, FieldDefinitionBuilder builder);
}

abstract class MethodTypeMacro implements TypeMacro {
  void visitMethodType(MethodType type, TypeBuilder builder);
}

abstract class MethodDeclarationMacro implements DeclarationMacro {
  void visitMethodDeclaration(
      MethodDeclaration declaration, ClassDeclarationBuilder builder);
}

abstract class MethodDefinitionMacro implements DefinitionMacro {
  void visitMethodDefinition(
      MethodDefinition definition, MethodDefinitionBuilder builder);
}

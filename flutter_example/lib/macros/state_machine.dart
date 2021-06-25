import 'package:macro_builder/definition.dart';

class StateMachine
    implements
        ClassDeclarationMacro,
        MethodDeclarationMacro,
        MethodDefinitionMacro {
  StateMachine({required this.actions});
  final Object actions;

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    for (final constructor in declaration.constructors) {
      builder.addToLibrary(Declaration('class ${constructor.name}')
          );
          dataClass.visitClassDeclaration(ClassDeclaration(), builder)
    }
  }

  @override
  void visitMethodDeclaration(
      MethodDeclaration declaration, ClassDeclarationBuilder builder) {
    // TODO: implement visitMethodDeclaration
  }

  @override
  void visitMethodDefinition(
      MethodDefinition definition, FunctionDefinitionBuilder builder) {
    // TODO: implement visitMethodDefinition
  }
}

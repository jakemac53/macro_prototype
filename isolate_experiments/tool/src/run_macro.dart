import 'package:macro_builder/definition.dart';
import 'package:isolate_experiments/protocol.dart';

// START MACRO IMPORTS MARKER
// END MACRO IMPORTS MARKER

RunMacroResponse runMacro(RunMacroRequest request) {
  var watch = Stopwatch()..start();
  Macro? macro; // Gets built in the switch
  switch (request.identifier) {
    // START MACRO CASE MARKER
    // END MACRO CASE MARKER

    default:
      throw StateError('Unknown macro ${request.identifier}');
  }

  final declaration =
      getDeclaration(GetDeclarationRequest(request.declarationDescriptor))
          .declaration;
  late GenericBuilder builder;
  switch (request.phase) {
    case Phase.type:
      builder = GenericTypeBuilder();
      if (macro is ClassTypeMacro && declaration is ClassType) {
        macro.visitClassType(declaration as ClassType, builder as TypeBuilder);
      } else if (macro is FieldTypeMacro && declaration is FieldType) {
        macro.visitFieldType(declaration as FieldType, builder as TypeBuilder);
      } else if (macro is FunctionTypeMacro && declaration is FunctionType) {
        macro.visitFunctionType(
            declaration as FunctionType, builder as TypeBuilder);
      } else if (macro is MethodTypeMacro && declaration is MethodType) {
        macro.visitMethodType(
            declaration as MethodType, builder as TypeBuilder);
      } else if (macro is ConstructorTypeMacro &&
          declaration is ConstructorType) {
        macro.visitConstructorType(
            declaration as ConstructorType, builder as TypeBuilder);
      } else {
        // TODO: Fix other side to check the declaration types
        // throw StateError('Unable to run $macro on $declaration');
      }
      break;
    case Phase.declaration:
      if (macro is ClassDeclarationMacro && declaration is ClassDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitClassDeclaration(declaration as ClassDeclaration,
            builder as ClassDeclarationBuilder);
      } else if (macro is FieldDeclarationMacro &&
          declaration is FieldDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitFieldDeclaration(declaration as FieldDeclaration,
            builder as ClassDeclarationBuilder);
      } else if (macro is FunctionDeclarationMacro &&
          declaration is FunctionDeclaration) {
        builder = GenericDeclarationBuilder();
        macro.visitFunctionDeclaration(declaration as FunctionDeclaration,
            builder as GenericDeclarationBuilder);
      } else if (macro is MethodDeclarationMacro &&
          declaration is MethodDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitMethodDeclaration(declaration as MethodDeclaration,
            builder as ClassDeclarationBuilder);
      } else if (macro is ConstructorDeclarationMacro &&
          declaration is ConstructorDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitConstructorDeclaration(declaration as ConstructorDeclaration,
            builder as ClassDeclarationBuilder);
      } else {
        // TODO: Fix other side to check the declaration types
        builder = GenericTypeBuilder();
        // throw StateError('Unable to run $macro on $declaration');
      }
      break;
    case Phase.definition:
      if (macro is FieldDefinitionMacro && declaration is FieldDefinition) {
        builder = GenericFieldDefinitionBuilder();
        macro.visitFieldDefinition(
            declaration as FieldDefinition, builder as FieldDefinitionBuilder);
      } else if (macro is FunctionDefinitionMacro &&
          declaration is FunctionDefinition) {
        builder = GenericFunctionDefinitionBuilder();
        macro.visitFunctionDefinition(declaration as FunctionDefinition,
            builder as FunctionDefinitionBuilder);
      } else if (macro is MethodDefinitionMacro &&
          declaration is MethodDefinition) {
        builder = GenericFunctionDefinitionBuilder();
        macro.visitMethodDefinition(declaration as MethodDefinition,
            builder as FunctionDefinitionBuilder);
      } else if (macro is ConstructorDefinitionMacro &&
          declaration is ConstructorDefinition) {
        builder = GenericConstructorDefinitionBuilder();
        macro.visitConstructorDefinition(declaration as ConstructorDefinition,
            builder as ConstructorDefinitionBuilder);
      } else {
        // TODO: Fix other side to check the declaration types
        builder = GenericTypeBuilder();
        // throw StateError('Unable to run $macro on $declaration');
      }
      break;
  }
  watch.stop();
  return RunMacroResponse("""
elapsed internal:(${watch.elapsed})
code: ${builder.builtCode.join('\n\n')}
""");
}

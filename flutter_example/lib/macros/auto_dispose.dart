import 'package:macro_builder/macro_builder.dart';

const autoDisposeMacro = _AutoDisposeMacro();

class _AutoDisposeMacro
    implements ClassDeclarationMacro, MethodDefinitionMacro {
  const _AutoDisposeMacro();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    if (declaration.methods.any((d) => d.name == 'dispose')) {
      throw ArgumentError(
          'Class ${declaration.name} already has a `dispose` method but was '
          'annotated with @autoDispose. If you want to augment the existing '
          'method body then annotate the method directly.');
    }

    builder.addToClass(Declaration('''
@autoDispose
external void dispose(); 
'''));
  }

  @override
  void visitMethodDefinition(
      MethodDefinition definition, FunctionDefinitionBuilder builder) {
    var disposeCalls = <Statement>[];
    for (var field in definition.definingClass.fields) {
      var type = field.type;
      if (type is! ClassDefinition) continue;
      // TODO: use isSubtypeOf if/once implemented.
      if (!type.superinterfaces.any((i) => i.name == 'Disposable')) continue;
      disposeCalls.add(Statement('${field.name}.dispose();'));
    }
    // Provide a full implementation if not yet implemented, otherwise just
    // prepend extra calls.
    if (definition.isAbstract || definition.isExternal) {
      builder.implement(FunctionBody.fromParts(['{', ...disposeCalls, '}']));
    } else {
      builder.wrapBody(before: disposeCalls);
    }
  }
}

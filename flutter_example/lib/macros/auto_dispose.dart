import 'package:macro_builder/definition.dart';

const autoDispose = _AutoDisposeMacro();

// Interface for disposable things.
abstract class Disposable {
  void dispose();
}

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
@override
@autoDispose
external void dispose(); 
'''));
  }

  @override
  void visitMethodDefinition(
      MethodDefinition definition, FunctionDefinitionBuilder builder) {
    var disposable = builder.typeDefinitionOf<Disposable>();
    var disposeCalls = <Statement>[];
    for (var field in definition.definingClass.fields) {
      var type = field.type;
      if (type is! ClassDefinition) continue;
      if (!type.isSubtype(disposable)) continue;
      disposeCalls.add(Statement('${field.name}.dispose();'));
    }
    // Provide a full implementation if not yet implemented, otherwise just
    // prepend extra calls.
    if (definition.isAbstract || definition.isExternal) {
      builder.implement(FunctionBody.fromParts(
          ['{', Statement('super.dispose();'), ...disposeCalls, '}']));
    } else {
      builder.wrapBody(before: disposeCalls);
    }
  }
}

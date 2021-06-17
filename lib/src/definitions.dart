import 'code.dart';
import 'declarations.dart';

abstract class TypeDefinition implements TypeDeclaration {
  @override
  Iterable<TypeDefinition> get typeArguments;

  @override
  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class ClassDefinition implements TypeDefinition, ClassDeclaration {
  @override
  Iterable<MethodDefinition> get constructors;

  @override
  Iterable<MethodDefinition> get methods;

  @override
  Iterable<FieldDefinition> get fields;

  @override
  ClassDefinition? get superclass;

  @override
  Iterable<TypeDefinition> get superinterfaces;
}

abstract class FunctionDefinition implements FunctionDeclaration {
  @override
  String get name;

  @override
  TypeDefinition get returnType;

  @override
  Iterable<ParameterDefinition> get positionalParameters;

  @override
  Map<String, ParameterDefinition> get namedParameters;

  @override
  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class MethodDefinition
    implements FunctionDefinition, MethodDeclaration {
  @override
  ClassDefinition get definingClass;
}

abstract class FieldDefinition implements FieldDeclaration {
  ClassDefinition? get definingClass;

  @override
  String get name;

  @override
  TypeDefinition get type;
}

abstract class ParameterDefinition implements ParameterDeclaration {
  @override
  TypeDefinition get type;
}

abstract class TypeParameterDefinition implements TypeParameterDeclaration {
  @override
  TypeDefinition? get bounds;
}

abstract class FieldDefinitionBuilder {
  /// Implement this as a normal field and supply an initializer.
  void withInitializer(Code body, {List<Code>? supportingDeclarations});

  /// Implement this as a getter/setter pair, with an optional new backing
  /// field.
  void withGetterSetterPair(Code getter, Code setter,
      {List<Code>? supportingDeclarations});
}

abstract class FunctionDefinitionBuilder {
  void implement(Code body, {List<Code>? supportingDeclarations});

  /// Used to wrap the body of a function, by running some code before or after
  /// the original body.
  ///
  /// Note that the original function will not have access to code from [before]
  /// or [after], and also [after] will not have access to anything from the
  /// scope of the original function body. However, [before] and [after] do
  /// share the same scope, so [after] can reference variables defined in
  /// [before].
  ///
  /// You can conceptually think of the wrapping as implemented like this when
  /// understanding the semantics:
  ///
  ///   void someFunction(int x) {
  ///     void originalFn(int x) {
  ///       // Copy the original function body here
  ///     }
  ///
  ///     // Inject all [before] code here.
  ///
  ///     // Call function matching the original, capture the return value to
  ///     // return later. Note that [ret] should not be available to [after].
  ///     var ret = originalFn(x);
  ///
  ///     // Inject all [after] code here.
  ///
  ///     return ret; // Return the original return value
  ///   }
  ///
  /// Note that this means [before] can modify parameters before they are
  /// passed into the original function.
  void wrapBody(
      {List<Statement>? before,
      List<Statement>? after,
      List<Declaration>? supportingDeclarations});
}

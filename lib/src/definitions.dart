import 'code.dart';
import 'declarations.dart';

abstract class TypeDefinition implements TypeDeclaration {
  Iterable<MethodDefinition> get constructors;

  Iterable<FieldDefinition> get fields;

  Iterable<MethodDefinition> get methods;

  TypeDefinition? get superclass;

  Iterable<TypeDefinition> get superinterfaces;

  Iterable<TypeDefinition> get typeArguments;

  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class ClassDefinition implements TypeDefinition {
  Iterable<MethodDefinition> get constructors;

  Iterable<MethodDefinition> get methods;

  Iterable<FieldDefinition> get fields;
}

abstract class MethodDefinition implements MethodDeclaration {
  String get name;

  TypeDefinition get returnType;

  Iterable<ParameterDefinition> get positionalParameters;

  Map<String, ParameterDefinition> get namedParameters;

  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class FieldDefinition implements FieldDeclaration {
  String get name;

  TypeDefinition get type;
}

abstract class ParameterDefinition implements ParameterDeclaration {
  TypeDefinition get type;
}

abstract class TypeParameterDefinition implements TypeParameterDeclaration {
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

abstract class MethodDefinitionBuilder {
  void implement(Code body, {List<Code>? supportingDeclarations});
}

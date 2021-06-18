import 'declarations.dart';

/// Type annotation introspection information for [DefinitionMacro]s.
abstract class TypeDefinition implements TypeDeclaration {
  @override
  Iterable<TypeDefinition> get typeArguments;

  @override
  Iterable<TypeParameterDefinition> get typeParameters;
}

/// Class introspection information for [DefinitionMacro]s.
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

/// Function introspection information for [DefinitionMacro]s.
abstract class FunctionDefinition implements FunctionDeclaration {
  @override
  TypeDefinition get returnType;

  @override
  Iterable<ParameterDefinition> get positionalParameters;

  @override
  Map<String, ParameterDefinition> get namedParameters;

  @override
  Iterable<TypeParameterDefinition> get typeParameters;
}

/// Method introspection information for [DefinitionMacro]s.
abstract class MethodDefinition
    implements FunctionDefinition, MethodDeclaration {
  @override
  ClassDefinition get definingClass;
}

/// Constructor introspection information for [DefinitionMacro]s.
abstract class ConstructorDefinition
    implements ConstructorDeclaration, MethodDefinition {}

/// Field introspection information for [DefinitionMacro]s.
abstract class FieldDefinition implements FieldDeclaration {
  ClassDefinition? get definingClass;

  @override
  TypeDefinition get type;
}

/// Parameter introspection information for [DefinitionMacro]s.
abstract class ParameterDefinition implements ParameterDeclaration {
  @override
  TypeDefinition get type;
}

/// Type parameter introspection information for [DefinitionMacro]s.
abstract class TypeParameterDefinition implements TypeParameterDeclaration {
  @override
  TypeDefinition? get bounds;
}

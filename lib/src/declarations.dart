import 'macro.dart';
import 'types.dart';

/// Type annotation introspection information for [DeclarationMacro]s.
abstract class TypeDeclaration implements TypeReference, DeclarationType {
  @override
  Iterable<TypeDeclaration> get typeArguments;

  Iterable<TypeParameterDeclaration> get typeParameters;

  bool isSubtype(TypeDeclaration other);
}

/// Class introspection information for [DeclarationMacro]s.
abstract class ClassDeclaration implements TypeDeclaration, ClassType {
  Iterable<MethodDeclaration> get constructors;

  Iterable<FieldDeclaration> get fields;

  Iterable<MethodDeclaration> get methods;

  @override
  ClassDeclaration? get superclass;

  @override
  Iterable<TypeDeclaration> get superinterfaces;
}

/// Function introspection information for [DeclarationMacro]s.
abstract class FunctionDeclaration implements FunctionType {
  @override
  TypeDeclaration get returnType;

  @override
  Iterable<ParameterDeclaration> get positionalParameters;

  @override
  Map<String, ParameterDeclaration> get namedParameters;

  @override
  Iterable<TypeParameterDeclaration> get typeParameters;
}

/// Method introspection information for [DeclarationMacro]s.
abstract class MethodDeclaration implements FunctionDeclaration, MethodType {}

/// Constructor introspection information for [DeclarationMacro]s.
abstract class ConstructorDeclaration
    implements ConstructorType, MethodDeclaration {}

/// Field introspection information for [DeclarationMacro]s.
abstract class FieldDeclaration implements FieldType {
  @override
  TypeDeclaration get type;
}

/// Parameter introspection information for [DeclarationMacro]s.
abstract class ParameterDeclaration implements ParameterType {
  @override
  TypeDeclaration get type;
}

/// TypeParameter introspection information for [DeclarationMacro]s.
abstract class TypeParameterDeclaration implements TypeParameterType {
  @override
  TypeDeclaration? get bounds;
}

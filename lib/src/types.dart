import 'code.dart';

/// Type annotation introspection information for [TypeMacro]s.
abstract class TypeReference {
  /// Whether or not the type reference is explicitly nullable (contains a
  /// trailing `?`)
  bool get isNullable;

  /// The name of the type as it exists in the type annotation.
  String get name;

  /// Emits a piece of code that concretely refers to the same type that is
  /// referred to by [this], regardless of where in the program it is placed.
  ///
  /// Effectively, this type reference has a custom scope (equal to [scope])
  /// instead of the standard lexical scope.
  Code get reference;

  /// The scope in which the type reference appeared in the program.
  Scope get scope;

  /// The type arguments, if applicable.
  Iterable<TypeReference> get typeArguments;
}

/// Declaration introspection information for [TypeMacro]s.
abstract class DeclarationType {
  bool get isAbstract;

  bool get isExternal;

  String get name;
}

/// Class introspection information for [TypeMacro]s.
abstract class ClassType implements TypeReference, DeclarationType {
  TypeReference? get superclass;

  Iterable<TypeReference> get superinterfaces;
}

/// Function introspection information for [TypeMacro]s.
abstract class FunctionType implements DeclarationType {
  bool get isGetter;

  bool get isSetter;

  TypeReference get returnType;

  Iterable<ParameterType> get positionalParameters;

  Map<String, ParameterType> get namedParameters;

  Iterable<TypeParameterType> get typeParameters;
}

/// Method introspection information for [TypeMacro]s.
abstract class MethodType implements FunctionType {
  TypeReference get definingClass;
}

/// Constructor introspection information for [TypeMacro]s.
abstract class ConstructorType implements MethodType {
  bool get isFactory;
}

/// Field introspection information for [TypeMacro]s.
abstract class FieldType implements DeclarationType {
  TypeReference get type;
}

/// Parameter introspection information for [TypeMacro]s.
abstract class ParameterType {
  String get name;

  TypeReference get type;

  bool get required;
}

/// Type parameter introspection information for [TypeMacro]s.
abstract class TypeParameterType {
  TypeReference? get bounds;

  String get name;
}

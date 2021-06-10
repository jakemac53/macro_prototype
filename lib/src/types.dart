import 'code.dart';

abstract class TypeReference {
  String get name;

  bool get isNullable;

  // The scope where the type reference should be resolved from.
  Scope get scope;

  Code get reference;
}

abstract class DeclarationType {
  bool get isAbstract;

  bool get isExternal;

  String get name;
}

abstract class ClassType implements TypeReference, DeclarationType {
  // TODO: Get TypeReferences for superclass and superinterfaces?
}

abstract class MethodType implements DeclarationType {
  bool get isGetter;

  bool get isSetter;

  TypeReference get returnType;

  Iterable<ParameterType> get positionalParameters;

  Map<String, ParameterType> get namedParameters;

  Iterable<TypeParameterType> get typeParameters;
}

abstract class FieldType implements DeclarationType {
  TypeReference get type;
}

abstract class ParameterType {
  String get name;

  TypeReference get type;

  bool get required;
}

abstract class TypeParameterType {
  TypeReference? get bounds;

  String get name;
}

abstract class TypeBuilder {
  void addTypeToLibary(Code declaration);
}

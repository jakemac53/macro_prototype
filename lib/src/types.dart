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

abstract class TargetClassType implements TypeReference, DeclarationType {
  void addTypeToLibary(Code declaration);
}

abstract class MethodType implements DeclarationType {
  bool get isGetter;

  bool get isSetter;

  TypeReference get returnType;

  Iterable<ParameterType> get positionalParameters;

  Map<String, ParameterType> get namedParameters;

  Iterable<TypeParameterType> get typeParameters;
}

abstract class TargetMethodType implements MethodType {
  void addTypeToLibary(Code declaration);
}

abstract class FieldType implements DeclarationType {
  TypeReference get type;
}

abstract class TargetFieldType implements FieldType {
  void addTypeToLibary(Code declaration);
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

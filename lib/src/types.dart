import 'code.dart';

abstract class TypeReference {
  String get name;

  bool get isNullable;

  // The scope where the type reference should be resolved from.
  Scope get scope;

  Code get reference;
}

abstract class TargetClassType implements TypeReference {
  void addTypeToLibary(Code declaration);
}

abstract class MethodType {
  String get name;

  TypeReference get returnType;

  Iterable<ParameterType> get positionalParameters;

  Map<String, ParameterType> get namedParameters;

  Iterable<TypeParameterType> get typeParameters;
}

abstract class TargetMethodType implements MethodType {
  void addTypeToLibary(Code declaration);
}

abstract class FieldType {
  String get name;

  TypeReference get type;
}

abstract class TargetFieldType implements FieldType {
  void addTypeToLibary(Code declaration);
}

abstract class ParameterType {
  TypeReference get type;
  String get name;
  bool get required;
}

abstract class TypeParameterType {
  String get name;
  TypeReference? get bounds;
}

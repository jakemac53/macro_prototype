import 'code.dart';

abstract class Macro {}

abstract class ClassTypeMacro implements Macro {
  void type(TargetClassType type);
}

abstract class ClassDeclarationMacro implements Macro {
  void declare(TargetClassDeclaration declaration);
}

abstract class ClassDefinitionMacro implements Macro {
  void define(TargetClassDefinition definition);
}

abstract class FieldTypeMacro implements Macro {
  void type(TargetFieldType type);
}

abstract class FieldDeclarationMacro implements Macro {
  void declare(TargetFieldDeclaration declaration);
}

abstract class FieldDefinitionMacro implements Macro {
  void define(TargetFieldDefinition definition);
}

abstract class MethodTypeMacro implements Macro {
  void type(TargetMethodType type);
}

abstract class MethodDeclarationMacro implements Macro {
  void declare(TargetMethodDeclaration declaration);
}

abstract class MethodDefinitionMacro implements Macro {
  void define(TargetMethodDefinition definition);
}

abstract class TypeReference {
  String get name;

  bool get isNullable;

  // The scope where the type reference should be resolved from.
  Scope get scope;

  Iterable<TypeReference> get typeArguments;

  Iterable<TypeParameterType> get typeParameters;
}

abstract class TypeDeclaration implements TypeReference {
  Iterable<TypeDeclaration> get typeArguments;

  Iterable<TypeParameterDeclaration> get typeParameters;

  bool isSubtype(TypeDeclaration other);
}

abstract class TypeDefinition implements TypeDeclaration {
  Iterable<TypeDefinition> get superinterfaces;

  Iterable<MethodDefinition> get methods;

  Iterable<FieldDefinition> get fields;
}

abstract class TargetClassType implements TypeReference {
  void addTypeToLibary(Code declaration);
}

abstract class TargetClassDeclaration implements TypeDeclaration {
  Iterable<TargetMethodDeclaration> get methods;

  Iterable<TargetFieldDeclaration> get fields;

  void addToClass(Code declaration);

  void addToLibrary(Code declaration);
}

abstract class TargetClassDefinition implements TypeDefinition {
  Iterable<TargetMethodDefinition> get methods;

  Iterable<TargetFieldDefinition> get fields;
}

abstract class MethodType {
  String get name;

  TypeReference get returnType;

  Iterable<ParameterType> get positionalParameters;

  Map<String, ParameterType> get namedParameters;

  Iterable<TypeParameterType> get typeParameters;
}

abstract class MethodDeclaration implements MethodType {
  TypeDeclaration get returnType;

  Iterable<ParameterDeclaration> get positionalParameters;

  Map<String, ParameterDeclaration> get namedParameters;

  Iterable<TypeParameterDeclaration> get typeParameters;
}

abstract class MethodDefinition implements MethodDeclaration {
  String get name;

  TypeDefinition get returnType;

  Iterable<ParameterDefinition> get positionalParameters;

  Map<String, ParameterDefinition> get namedParameters;

  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class TargetMethodType implements MethodType {
  void addTypeToLibary(Code declaration);
}

abstract class TargetMethodDeclaration implements MethodDeclaration {
  void addToClass(Code declaration);
}

abstract class TargetMethodDefinition implements MethodDefinition {
  void implement(Code body, {List<Code>? supportingDeclarations});
}

abstract class FieldType {
  String get name;

  TypeReference get type;
}

abstract class FieldDeclaration implements FieldType {
  String get name;

  TypeDeclaration get type;
}

abstract class FieldDefinition implements FieldDeclaration {
  String get name;

  TypeDefinition get type;
}

abstract class TargetFieldType implements FieldType {
  void addTypeToLibary(Code declaration);
}

abstract class TargetFieldDeclaration implements FieldDeclaration {
  void addToClass(Code declaration);
}

abstract class TargetFieldDefinition implements FieldDefinition {
  /// Implement this as a normal field and supply an initializer.
  void withInitializer(Code body, {List<Code>? supportingDeclarations});

  /// Implement this as a getter/setter pair, with an optional new backing
  /// field.
  void withGetterSetterPair(Code getter, Code setter,
      {List<Code>? supportingDeclarations});
}

abstract class ParameterType {
  TypeReference get type;
  String get name;
  bool get required;
}

abstract class ParameterDeclaration implements ParameterType {
  TypeDeclaration get type;
}

abstract class ParameterDefinition implements ParameterDeclaration {
  TypeDefinition get type;
}

abstract class TypeParameterType {
  String get name;
  TypeReference? get bounds;
}

abstract class TypeParameterDeclaration implements TypeParameterType {
  TypeDeclaration? get bounds;
}

abstract class TypeParameterDefinition implements TypeParameterDeclaration {
  TypeDefinition? get bounds;
}

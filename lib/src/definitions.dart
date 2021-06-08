import 'code.dart';
import 'declarations.dart';

abstract class TypeDefinition implements TypeDeclaration {
  Iterable<FieldDefinition> get fields;

  Iterable<MethodDefinition> get methods;

  Iterable<TypeDefinition> get superinterfaces;

  Iterable<TypeDefinition> get typeArguments;

  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class TargetClassDefinition implements TypeDefinition {
  Iterable<TargetMethodDefinition> get constructors;

  Iterable<TargetMethodDefinition> get methods;

  Iterable<TargetFieldDefinition> get fields;
}

abstract class MethodDefinition implements MethodDeclaration {
  String get name;

  TypeDefinition get returnType;

  Iterable<ParameterDefinition> get positionalParameters;

  Map<String, ParameterDefinition> get namedParameters;

  Iterable<TypeParameterDefinition> get typeParameters;
}

abstract class TargetMethodDefinition implements MethodDefinition {
  void implement(Code body, {List<Code>? supportingDeclarations});
}

abstract class FieldDefinition implements FieldDeclaration {
  String get name;

  TypeDefinition get type;
}

abstract class TargetFieldDefinition implements FieldDefinition {
  /// Implement this as a normal field and supply an initializer.
  void withInitializer(Code body, {List<Code>? supportingDeclarations});

  /// Implement this as a getter/setter pair, with an optional new backing
  /// field.
  void withGetterSetterPair(Code getter, Code setter,
      {List<Code>? supportingDeclarations});
}

abstract class ParameterDefinition implements ParameterDeclaration {
  TypeDefinition get type;
}

abstract class TypeParameterDefinition implements TypeParameterDeclaration {
  TypeDefinition? get bounds;
}

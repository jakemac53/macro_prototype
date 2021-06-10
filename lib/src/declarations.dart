import 'code.dart';
import 'types.dart';

abstract class TypeDeclaration implements TypeReference, DeclarationType {
  TypeDeclaration? get superclass;

  Iterable<TypeDeclaration> get superinterfaces;

  Iterable<TypeDeclaration> get typeArguments;

  Iterable<TypeParameterDeclaration> get typeParameters;

  bool isSubtype(TypeDeclaration other);
}

abstract class ClassDeclaration extends TypeDeclaration {
  Iterable<MethodDeclaration> get constructors;

  Iterable<FieldDeclaration> get fields;

  Iterable<MethodDeclaration> get methods;
}

abstract class MethodDeclaration implements MethodType {
  TypeDeclaration get returnType;

  Iterable<ParameterDeclaration> get positionalParameters;

  Map<String, ParameterDeclaration> get namedParameters;

  Iterable<TypeParameterDeclaration> get typeParameters;
}

abstract class FieldDeclaration implements FieldType {
  String get name;

  TypeDeclaration get type;
}

abstract class ParameterDeclaration implements ParameterType {
  TypeDeclaration get type;
}

abstract class TypeParameterDeclaration implements TypeParameterType {
  TypeDeclaration? get bounds;
}

abstract class DeclarationBuilder {
  void addToLibrary(Code declaration);
}

abstract class ClassDeclarationBuilder implements DeclarationBuilder {
  // TODO: If we want library level macros that can have a declaration phase
  // that adds stuff to classes, then this should take a parameter to identify
  // which class [declaration] should be added to.
  void addToClass(Code declaration);
}

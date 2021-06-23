import 'package:analyzer/dart/element/element.dart' as analyzer;
import 'package:analyzer/dart/element/nullability_suffix.dart' as analyzer;
import 'package:analyzer/dart/element/type.dart' as analyzer;

import 'code.dart';
import 'definitions.dart';
import 'declarations.dart';
import 'types.dart';

class AnalyzerTypeReference implements TypeReference {
  final analyzer.TypeDefiningElement element;
  final analyzer.DartType originalReference;

  AnalyzerTypeReference(this.element, {required this.originalReference});

  @override
  bool get isNullable =>
      originalReference.nullabilitySuffix ==
      analyzer.NullabilitySuffix.question;

  @override
  String get name => element.name!;

  @override
  Scope get scope => throw UnimplementedError();

  @override
  Iterable<TypeReference> get typeArguments sync* {
    var reference = originalReference;
    if (reference is analyzer.ParameterizedType) {
      for (var typeArgument in reference.typeArguments) {
        yield AnalyzerTypeReference(
            typeArgument.element! as analyzer.TypeDefiningElement,
            originalReference: typeArgument);
      }
    }
  }

  @override
  // TODO: Scope, once we have that
  Code get reference => Fragment('$name${isNullable ? '?' : ''}');
}

abstract class AnalyzerDeclarationType implements DeclarationType {
  analyzer.TypeDefiningElement get element;

  @override
  bool get isAbstract {
    var e = element;
    if (e is! analyzer.ClassElement) return false;
    return e.isAbstract;
  }

  @override
  bool get isExternal {
    var e = element;
    if (e is! analyzer.ClassElement) return false;
    throw UnsupportedError(
        'Analyzer doesn\'t appear to have an isExternal getter for classes?');
  }
}

class AnalyzerTypeDeclaration extends AnalyzerTypeReference
    implements TypeDeclaration {
  AnalyzerTypeDeclaration._(analyzer.TypeDefiningElement element,
      {required analyzer.DartType originalReference})
      : super(element, originalReference: originalReference);

  factory AnalyzerTypeDeclaration(analyzer.TypeDefiningElement element,
          {required analyzer.DartType originalReference}) =>
      element is analyzer.ClassElement
          ? AnalyzerClassDeclaration(element,
              originalReference: originalReference)
          : AnalyzerTypeDeclaration._(element,
              originalReference: originalReference);

  @override
  bool isSubtype(TypeDeclaration other) {
    other = other as AnalyzerTypeDeclaration;
    return other.element.library!.typeSystem
        .isSubtypeOf(originalReference, other.originalReference);
  }

  @override
  bool get isAbstract {
    var e = element;
    if (e is! analyzer.ClassElement) return false;
    return e.isAbstract;
  }

  @override
  bool get isExternal {
    var e = element;
    if (e is! analyzer.ClassElement) return false;
    throw UnsupportedError(
        'Analyzer doesn\'t appear to have an isExternal getter for classes?');
  }

  @override
  Iterable<TypeDeclaration> get typeArguments sync* {
    var reference = originalReference;
    if (reference is analyzer.ParameterizedType) {
      for (var typeArgument in reference.typeArguments) {
        yield AnalyzerTypeDeclaration(
            typeArgument.element! as analyzer.TypeDefiningElement,
            originalReference: typeArgument);
      }
    }
  }

  @override
  Iterable<TypeParameterDeclaration> get typeParameters sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var parameter in e.typeParameters) {
        yield AnalyzerTypeParameterDeclaration(parameter);
      }
    }
  }
}

class AnalyzerTypeDefinition extends AnalyzerTypeDeclaration
    implements TypeDefinition {
  AnalyzerTypeDefinition._(analyzer.TypeDefiningElement element,
      {required analyzer.DartType originalReference})
      : super._(element, originalReference: originalReference);

  factory AnalyzerTypeDefinition(analyzer.TypeDefiningElement element,
          {required analyzer.DartType originalReference}) =>
      element is analyzer.ClassElement
          ? AnalyzerClassDefinition(element,
              originalReference: originalReference)
          : AnalyzerTypeDefinition._(element,
              originalReference: originalReference);

  @override
  Iterable<TypeDefinition> get typeArguments sync* {
    var reference = originalReference;
    if (reference is analyzer.ParameterizedType) {
      for (var typeArgument in reference.typeArguments) {
        yield AnalyzerTypeDefinition(
            typeArgument.element as analyzer.TypeDefiningElement,
            originalReference: typeArgument);
      }
    }
  }

  @override
  Iterable<TypeParameterDefinition> get typeParameters sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var parameter in e.typeParameters) {
        yield AnalyzerTypeParameterDefinition(parameter);
      }
    }
  }
}

class AnalyzerClassType extends AnalyzerTypeReference
    with AnalyzerDeclarationType
    implements ClassType {
  AnalyzerClassType(analyzer.TypeDefiningElement element,
      {required analyzer.DartType originalReference})
      : super(element, originalReference: originalReference);

  @override
  TypeReference? get superclass {
    var e = element;
    if (e is analyzer.ClassElement && !e.isDartCoreObject) {
      var superType = e.supertype!;
      return AnalyzerClassType(superType.element, originalReference: superType);
    }
  }

  @override
  Iterable<TypeReference> get superinterfaces sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var interface in e.allSupertypes) {
        yield AnalyzerClassType(interface.element,
            originalReference: interface);
      }
    }
  }
}

class AnalyzerClassDeclaration extends AnalyzerTypeDeclaration
    implements ClassDeclaration {
  @override
  analyzer.ClassElement get element => super.element as analyzer.ClassElement;

  AnalyzerClassDeclaration(analyzer.ClassElement element,
      {required analyzer.DartType originalReference})
      : super._(element, originalReference: originalReference);

  @override
  Iterable<MethodDeclaration> get constructors sync* {
    for (var constructor in element.constructors) {
      if (constructor.isSynthetic) continue;
      yield AnalyzerConstructorDeclaration(constructor);
    }
  }

  @override
  Iterable<FieldDeclaration> get fields sync* {
    for (var field in element.fields) {
      if (field.isSynthetic) continue;
      yield AnalyzerFieldDeclaration(field);
    }
  }

  @override
  Iterable<MethodDeclaration> get methods sync* {
    for (var method in element.methods) {
      if (method.isSynthetic) continue;
      yield AnalyzerMethodDeclaration(method);
    }
  }

  @override
  ClassDeclaration? get superclass {
    if (!element.isDartCoreObject) {
      var superType = element.supertype!;
      return AnalyzerClassDeclaration(superType.element,
          originalReference: superType);
    }
  }

  @override
  Iterable<TypeDeclaration> get superinterfaces sync* {
    for (var interface in element.allSupertypes) {
      yield AnalyzerTypeDeclaration(interface.element,
          originalReference: interface);
    }
  }

  @override
  bool isSubtype(TypeDeclaration other) {
    if (other is! ClassDeclaration) return false;
    other = other as AnalyzerClassDeclaration;
    if (other.element == element) return true;
    return superinterfaces.first.isSubtype(other);
  }
}

class AnalyzerClassDefinition extends AnalyzerTypeDefinition
    implements ClassDefinition {
  AnalyzerClassDefinition(analyzer.TypeDefiningElement element,
      {required analyzer.DartType originalReference})
      : super._(element, originalReference: originalReference);

  @override
  Iterable<MethodDefinition> get constructors sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var constructor in e.constructors) {
        if (constructor.isSynthetic) continue;
        yield AnalyzerConstructorDefinition(constructor, parentClass: e);
      }
    }
  }

  @override
  Iterable<FieldDefinition> get fields sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var field in e.fields) {
        if (field.isSynthetic) continue;
        yield AnalyzerFieldDefinition(field, parentClass: e);
      }
    }
  }

  @override
  Iterable<MethodDefinition> get methods sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var method in e.methods) {
        if (method.isSynthetic) continue;
        yield AnalyzerMethodDefinition(method, parentClass: e);
      }
    }
  }

  @override
  ClassDefinition? get superclass {
    var e = element;
    if (e is analyzer.ClassElement && !e.isDartCoreObject) {
      var superType = e.supertype!;
      return AnalyzerClassDefinition(superType.element,
          originalReference: superType);
    }
  }

  @override
  Iterable<TypeDefinition> get superinterfaces sync* {
    var e = element;
    if (e is analyzer.ClassElement) {
      for (var interface in e.allSupertypes) {
        yield AnalyzerClassDefinition(interface.element,
            originalReference: interface);
      }
    }
  }
}

abstract class _AnalyzerFunctionType implements FunctionType {
  analyzer.ExecutableElement get element;

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => element.isExternal;

  @override
  bool get isGetter {
    var e = element;
    return e is analyzer.PropertyAccessorElement && e.isGetter;
  }

  @override
  bool get isSetter {
    var e = element;
    return e is analyzer.PropertyAccessorElement && e.isSetter;
  }

  @override
  String get name => element.name;

  @override
  Map<String, ParameterType> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: AnalyzerParameterType(param),
      };

  @override
  Iterable<ParameterType> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield AnalyzerParameterType(param);
    }
  }

  @override
  TypeReference get returnType => AnalyzerTypeReference(
      element.returnType.element! as analyzer.TypeDefiningElement,
      originalReference: element.returnType);

  @override
  Iterable<TypeParameterType> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterType(typeParam);
    }
  }
}

class AnalyzerFunctionType with _AnalyzerFunctionType {
  @override
  final analyzer.ExecutableElement element;
  AnalyzerFunctionType(this.element);
}

abstract class _AnalyzerFunctionDeclaration
    with _AnalyzerFunctionType
    implements FunctionDeclaration {
  @override
  Map<String, ParameterDeclaration> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: AnalyzerParameterDeclaration(param),
      };

  @override
  Iterable<ParameterDeclaration> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield AnalyzerParameterDeclaration(param);
    }
  }

  @override
  TypeDeclaration get returnType => AnalyzerTypeDeclaration(
      element.returnType.element! as analyzer.TypeDefiningElement,
      originalReference: element.returnType);

  @override
  Iterable<TypeParameterDeclaration> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterDeclaration(typeParam);
    }
  }
}

class AnalyzerFunctionDeclaration extends _AnalyzerFunctionDeclaration {
  @override
  final analyzer.ExecutableElement element;
  AnalyzerFunctionDeclaration(this.element);
}

class AnalyzerMethodType extends _AnalyzerFunctionDeclaration
    implements MethodDeclaration {
  @override
  final analyzer.ExecutableElement element;
  AnalyzerMethodType(this.element);

  @override
  TypeReference get definingClass {
    var clazz = element.enclosingElement as analyzer.ClassElement;
    return AnalyzerTypeReference(clazz, originalReference: clazz.thisType);
  }
}

class AnalyzerMethodDeclaration extends _AnalyzerFunctionDeclaration
    implements MethodDeclaration {
  @override
  final analyzer.ExecutableElement element;

  AnalyzerMethodDeclaration(this.element);

  @override
  TypeReference get definingClass {
    var clazz = element.enclosingElement as analyzer.ClassElement;
    return AnalyzerTypeReference(clazz, originalReference: clazz.thisType);
  }
}

abstract class _AnalyzerFunctionDefinition implements FunctionDefinition {
  analyzer.ExecutableElement get element;

  @override
  Map<String, ParameterDefinition> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: AnalyzerParameterDefinition(param),
      };

  @override
  Iterable<ParameterDefinition> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield AnalyzerParameterDefinition(param);
    }
  }

  @override
  TypeDefinition get returnType => element.returnType.element == null
      ? const VoidTypeDefinition()
      : AnalyzerTypeDefinition(
          element.returnType.element! as analyzer.TypeDefiningElement,
          originalReference: element.returnType);

  @override
  Iterable<TypeParameterDefinition> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterDefinition(typeParam);
    }
  }
}

class AnalyzerFunctionDefinition extends AnalyzerFunctionDeclaration
    with _AnalyzerFunctionDefinition {
  AnalyzerFunctionDefinition(analyzer.ExecutableElement element)
      : super(element);
}

class AnalyzerMethodDefinition extends AnalyzerMethodDeclaration
    with _AnalyzerFunctionDefinition
    implements MethodDefinition {
  final analyzer.ClassElement parentClass;

  AnalyzerMethodDefinition(analyzer.ExecutableElement element,
      {required this.parentClass})
      : super(element);

  @override
  ClassDefinition get definingClass => AnalyzerClassDefinition(parentClass,
      originalReference: parentClass.thisType);
}

class AnalyzerConstructorType implements ConstructorType {
  final analyzer.ConstructorElement element;

  AnalyzerConstructorType(this.element);

  @override
  TypeReference get definingClass {
    var clazz = element.enclosingElement;
    return AnalyzerTypeReference(clazz, originalReference: clazz.thisType);
  }

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => element.isExternal;

  @override
  bool get isFactory => element.isFactory;

  @override
  bool get isGetter => false;

  @override
  bool get isSetter => false;

  @override
  String get name => element.name;

  @override
  Map<String, ParameterType> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: AnalyzerParameterType(param),
      };

  @override
  Iterable<ParameterType> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield AnalyzerParameterType(param);
    }
  }

  @override
  TypeReference get returnType =>
      AnalyzerTypeReference(element.returnType.element,
          originalReference: element.returnType);

  @override
  Iterable<TypeParameterType> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterType(typeParam);
    }
  }
}

class AnalyzerConstructorDeclaration extends AnalyzerConstructorType
    implements ConstructorDeclaration {
  AnalyzerConstructorDeclaration(analyzer.ConstructorElement element)
      : super(element);
  @override
  Map<String, ParameterDeclaration> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: AnalyzerParameterDeclaration(param),
      };

  @override
  Iterable<ParameterDeclaration> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield AnalyzerParameterDeclaration(param);
    }
  }

  @override
  TypeDeclaration get returnType =>
      AnalyzerTypeDeclaration(element.returnType.element,
          originalReference: element.returnType);

  @override
  Iterable<TypeParameterDeclaration> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterDeclaration(typeParam);
    }
  }
}

class AnalyzerConstructorDefinition extends AnalyzerConstructorDeclaration
    implements ConstructorDefinition {
  final analyzer.ClassElement _parentClass;

  AnalyzerConstructorDefinition(analyzer.ConstructorElement element,
      {required analyzer.ClassElement parentClass})
      : _parentClass = parentClass,
        super(element);

  @override
  ClassDefinition get definingClass => AnalyzerClassDefinition(_parentClass,
      originalReference: _parentClass.thisType);

  @override
  Map<String, ParameterDefinition> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: AnalyzerParameterDefinition(param),
      };

  @override
  Iterable<ParameterDefinition> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield AnalyzerParameterDefinition(param);
    }
  }

  @override
  TypeDefinition get returnType =>
      AnalyzerTypeDefinition(element.returnType.element,
          originalReference: element.returnType);

  @override
  Iterable<TypeParameterDefinition> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterDefinition(typeParam);
    }
  }
}

class AnalyzerFieldDeclaration implements FieldDeclaration {
  final analyzer.FieldElement element;

  AnalyzerFieldDeclaration(this.element);

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => element.isExternal;

  @override
  String get name => element.name;

  @override
  TypeDeclaration get type => AnalyzerTypeDeclaration(
      element.type.element! as analyzer.TypeDefiningElement,
      originalReference: element.type);
}

class AnalyzerFieldDefinition extends AnalyzerFieldDeclaration
    implements FieldDefinition {
  final analyzer.ClassElement? _parentClass;

  AnalyzerFieldDefinition(analyzer.FieldElement element,
      {analyzer.ClassElement? parentClass})
      : _parentClass = parentClass,
        super(element);

  @override
  ClassDefinition? get definingClass => _parentClass == null
      ? null
      : AnalyzerClassDefinition(_parentClass!,
          originalReference: _parentClass!.thisType);

  @override
  TypeDefinition get type => AnalyzerTypeDefinition(
      element.type.element! as analyzer.TypeDefiningElement,
      originalReference: element.type);
}

class AnalyzerParameterType implements ParameterType {
  final analyzer.ParameterElement element;

  AnalyzerParameterType(this.element);

  @override
  String get name => element.name;

  @override
  bool get required => element.isRequiredPositional || element.isRequiredNamed;

  @override
  TypeReference get type => AnalyzerTypeReference(
      element.type.element! as analyzer.TypeDefiningElement,
      originalReference: element.type);
}

class AnalyzerParameterDeclaration extends AnalyzerParameterType
    implements ParameterDeclaration {
  AnalyzerParameterDeclaration(analyzer.ParameterElement element)
      : super(element);

  @override
  String get name => element.name;

  @override
  bool get required => element.isRequiredPositional || element.isRequiredNamed;

  @override
  TypeDeclaration get type => AnalyzerTypeDeclaration(
      element.type.element! as analyzer.TypeDefiningElement,
      originalReference: element.type);
}

class AnalyzerParameterDefinition extends AnalyzerParameterDeclaration
    implements ParameterDefinition {
  AnalyzerParameterDefinition(analyzer.ParameterElement element)
      : super(element);

  @override
  TypeDefinition get type => AnalyzerTypeDefinition(
      element.type.element! as analyzer.TypeDefiningElement,
      originalReference: element.type);
}

class AnalyzerTypeParameterType implements TypeParameterType {
  final analyzer.TypeParameterElement element;

  AnalyzerTypeParameterType(this.element);

  @override
  TypeReference? get bounds => element.bound == null
      ? null
      : AnalyzerTypeDeclaration(
          element.bound!.element! as analyzer.TypeDefiningElement,
          originalReference:
              element.bound ?? element.library!.typeProvider.objectType);

  @override
  String get name => element.name;
}

class AnalyzerTypeParameterDeclaration extends AnalyzerTypeParameterType
    implements TypeParameterDeclaration {
  AnalyzerTypeParameterDeclaration(analyzer.TypeParameterElement element)
      : super(element);

  @override
  TypeDeclaration? get bounds => element.bound == null
      ? null
      : AnalyzerTypeDeclaration(
          element.bound!.element! as analyzer.TypeDefiningElement,
          originalReference: element.bound!);
}

class AnalyzerTypeParameterDefinition extends AnalyzerTypeParameterDeclaration
    implements TypeParameterDefinition {
  AnalyzerTypeParameterDefinition(analyzer.TypeParameterElement element)
      : super(element);

  @override
  TypeDefinition? get bounds => element.bound == null
      ? null
      : AnalyzerTypeDefinition(
          element.bound!.element! as analyzer.TypeDefiningElement,
          originalReference: element.bound!);
}

class VoidTypeDeclaration implements TypeDeclaration {
  const VoidTypeDeclaration();

  @override
  bool get isAbstract => false;

  @override
  bool get isExternal => false;

  @override
  bool get isNullable => false;

  @override
  bool isSubtype(TypeDeclaration other) => false;

  @override
  String get name => 'void';

  @override
  Code get reference => TypeAnnotation('void');

  @override
  // TODO: implement scope
  Scope get scope => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get typeArguments => const [];

  @override
  Iterable<TypeParameterDefinition> get typeParameters => const [];
}

class VoidTypeDefinition extends VoidTypeDeclaration implements TypeDefinition {
  const VoidTypeDefinition() : super();
}

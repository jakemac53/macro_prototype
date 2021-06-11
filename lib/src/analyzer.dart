import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'code.dart';
import 'definitions.dart';
import 'declarations.dart';
import 'types.dart';

class AnalyzerTypeReference implements TypeReference {
  final TypeDefiningElement element;
  final DartType? originalReference;

  AnalyzerTypeReference(this.element, {this.originalReference});

  @override
  bool get isNullable =>
      originalReference?.nullabilitySuffix == NullabilitySuffix.question;

  @override
  String get name => element.name!;

  @override
  Scope get scope => throw UnimplementedError();

  @override
  // TODO: Scope, once we have that
  Code get reference => Code('$name${isNullable ? '?' : ''}');
}

abstract class AnalyzerDeclarationType implements DeclarationType {
  TypeDefiningElement get element;

  @override
  bool get isAbstract {
    var e = element;
    if (e is! ClassElement) return false;
    return e.isAbstract;
  }

  @override
  bool get isExternal {
    var e = element;
    if (e is! ClassElement) return false;
    throw UnsupportedError(
        'Analyzer doesn\'t appear to have an isExternal getter for classes?');
  }
}

class AnalyzerTypeDeclaration extends AnalyzerTypeReference
    implements TypeDeclaration {
  AnalyzerTypeDeclaration(TypeDefiningElement element,
      {DartType? originalReference})
      : super(element, originalReference: originalReference);

  @override
  bool isSubtype(TypeDeclaration other) => throw UnimplementedError();

  @override
  bool get isAbstract {
    var e = element;
    if (e is! ClassElement) return false;
    return e.isAbstract;
  }

  @override
  bool get isExternal {
    var e = element;
    if (e is! ClassElement) return false;
    throw UnsupportedError(
        'Analyzer doesn\'t appear to have an isExternal getter for classes?');
  }

  @override
  Iterable<TypeDeclaration> get typeArguments sync* {
    var reference = originalReference;
    if (reference is ParameterizedType) {
      for (var typeArgument in reference.typeArguments) {
        yield AnalyzerTypeDeclaration(
            typeArgument.element! as TypeDefiningElement,
            originalReference: typeArgument);
      }
    }
  }

  @override
  Iterable<TypeParameterDeclaration> get typeParameters sync* {
    var e = element;
    if (e is ClassElement) {
      for (var parameter in e.typeParameters) {
        yield AnalyzerTypeParameterDeclaration(parameter);
      }
    }
  }
}

class AnalyzerTypeDefinition extends AnalyzerTypeDeclaration
    implements TypeDefinition {
  AnalyzerTypeDefinition(TypeDefiningElement element,
      {DartType? originalReference})
      : super(element, originalReference: originalReference);

  @override
  bool isSubtype(TypeDeclaration other) => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get typeArguments sync* {
    var reference = originalReference;
    if (reference is ParameterizedType) {
      for (var typeArgument in reference.typeArguments) {
        yield AnalyzerTypeDefinition(
            typeArgument.element! as TypeDefiningElement,
            originalReference: typeArgument);
      }
    }
  }

  @override
  Iterable<TypeParameterDefinition> get typeParameters sync* {
    var e = element;
    if (e is ClassElement) {
      for (var parameter in e.typeParameters) {
        yield AnalyzerTypeParameterDefinition(parameter);
      }
    }
  }
}

class AnalyzerClassType extends AnalyzerTypeReference
    with AnalyzerDeclarationType
    implements ClassType {
  AnalyzerClassType(TypeDefiningElement element, {DartType? originalReference})
      : super(element, originalReference: originalReference);

  @override
  TypeReference? get superclass {
    var e = element;
    if (e is ClassElement && !e.isDartCoreObject) {
      var superType = e.supertype!;
      return AnalyzerClassType(superType.element, originalReference: superType);
    }
  }

  @override
  Iterable<TypeReference> get superinterfaces sync* {
    var e = element;
    if (e is ClassElement) {
      for (var interface in e.allSupertypes) {
        yield AnalyzerClassType(interface.element,
            originalReference: interface);
      }
    }
  }
}

class AnalyzerClassDeclaration extends AnalyzerTypeDeclaration
    implements ClassDeclaration {
  AnalyzerClassDeclaration(TypeDefiningElement element,
      {DartType? originalReference})
      : super(element, originalReference: originalReference);

  @override
  Iterable<MethodDeclaration> get constructors sync* {
    var e = element;
    if (e is ClassElement) {
      for (var constructor in e.constructors) {
        if (constructor.isSynthetic) continue;
        yield AnalyzerConstructorDeclaration(constructor);
      }
    }
  }

  @override
  Iterable<FieldDeclaration> get fields sync* {
    var e = element;
    if (e is ClassElement) {
      for (var field in e.fields) {
        if (field.isSynthetic) continue;
        yield AnalyzerFieldDeclaration(field);
      }
    }
  }

  @override
  Iterable<MethodDeclaration> get methods sync* {
    var e = element;
    if (e is ClassElement) {
      for (var method in e.methods) {
        if (method.isSynthetic) continue;
        yield AnalyzerMethodDeclaration(method);
      }
    }
  }

  @override
  TypeDeclaration? get superclass {
    var e = element;
    if (e is ClassElement && !e.isDartCoreObject) {
      var superType = e.supertype!;
      return AnalyzerTypeDeclaration(superType.element,
          originalReference: superType);
    }
  }

  @override
  Iterable<TypeDeclaration> get superinterfaces sync* {
    var e = element;
    if (e is ClassElement) {
      for (var interface in e.allSupertypes) {
        yield AnalyzerTypeDeclaration(interface.element,
            originalReference: interface);
      }
    }
  }
}

class AnalyzerClassDefinition extends AnalyzerTypeDefinition
    implements ClassDefinition {
  AnalyzerClassDefinition(TypeDefiningElement element,
      {DartType? originalReference})
      : super(element, originalReference: originalReference);

  @override
  Iterable<MethodDefinition> get constructors sync* {
    var e = element;
    if (e is ClassElement) {
      for (var constructor in e.constructors) {
        if (constructor.isSynthetic) continue;
        yield AnalyzerConstructorDefinition(constructor, parentClass: e);
      }
    }
  }

  @override
  Iterable<FieldDefinition> get fields sync* {
    var e = element;
    if (e is ClassElement) {
      for (var field in e.fields) {
        if (field.isSynthetic) continue;
        yield AnalyzerFieldDefinition(field, parentClass: e);
      }
    }
  }

  @override
  Iterable<MethodDefinition> get methods sync* {
    var e = element;
    if (e is ClassElement) {
      for (var method in e.methods) {
        if (method.isSynthetic) continue;
        yield AnalyzerMethodDefinition(method, parentClass: e);
      }
    }
  }

  @override
  TypeDefinition? get superclass {
    var e = element;
    if (e is ClassElement && !e.isDartCoreObject) {
      var superType = e.supertype!;
      return AnalyzerClassDefinition(superType.element,
          originalReference: superType);
    }
  }

  @override
  Iterable<TypeDefinition> get superinterfaces sync* {
    var e = element;
    if (e is ClassElement) {
      for (var interface in e.allSupertypes) {
        yield AnalyzerClassDefinition(interface.element,
            originalReference: interface);
      }
    }
  }
}

class AnalyzerMethodDeclaration implements MethodDeclaration {
  final ExecutableElement element;

  AnalyzerMethodDeclaration(this.element);

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => element.isExternal;

  @override
  bool get isGetter {
    var e = element;
    return e is PropertyAccessorElement && e.isGetter;
  }

  @override
  bool get isSetter {
    var e = element;
    return e is PropertyAccessorElement && e.isSetter;
  }

  @override
  String get name => element.name;

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
      element.returnType.element! as TypeDefiningElement,
      originalReference: element.returnType);

  @override
  Iterable<TypeParameterDeclaration> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterDeclaration(typeParam);
    }
  }
}

class AnalyzerMethodDefinition extends AnalyzerMethodDeclaration
    implements MethodDefinition {
  final ClassElement? _parentClass;

  AnalyzerMethodDefinition(ExecutableElement element,
      {ClassElement? parentClass})
      : _parentClass = parentClass,
        super(element);

  @override
  ClassDefinition? get definingClass =>
      _parentClass == null ? null : AnalyzerClassDefinition(_parentClass!);

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
      AnalyzerTypeDefinition(element.returnType.element! as TypeDefiningElement,
          originalReference: element.returnType);

  @override
  Iterable<TypeParameterDefinition> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield AnalyzerTypeParameterDefinition(typeParam);
    }
  }
}

class AnalyzerConstructorDeclaration implements MethodDeclaration {
  final ConstructorElement element;

  AnalyzerConstructorDeclaration(this.element);

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => element.isExternal;

  @override
  bool get isGetter => false;

  @override
  bool get isSetter => false;

  @override
  String get name => element.name;

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
    implements MethodDefinition {
  final ClassElement _parentClass;

  AnalyzerConstructorDefinition(ConstructorElement element,
      {required ClassElement parentClass})
      : _parentClass = parentClass,
        super(element);

  ClassDefinition get definingClass => AnalyzerClassDefinition(_parentClass);

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
  final FieldElement element;

  AnalyzerFieldDeclaration(this.element);

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => element.isExternal;

  @override
  String get name => element.name;

  @override
  TypeDeclaration get type =>
      AnalyzerTypeDeclaration(element.type.element! as TypeDefiningElement,
          originalReference: element.type);
}

class AnalyzerFieldDefinition extends AnalyzerFieldDeclaration
    implements FieldDefinition {
  final ClassElement? _parentClass;

  AnalyzerFieldDefinition(FieldElement element, {ClassElement? parentClass})
      : _parentClass = parentClass,
        super(element);

  ClassDefinition? get definingClass =>
      _parentClass == null ? null : AnalyzerClassDefinition(_parentClass!);

  @override
  TypeDefinition get type =>
      AnalyzerTypeDefinition(element.type.element! as TypeDefiningElement,
          originalReference: element.type);
}

class AnalyzerParameterDeclaration implements ParameterDeclaration {
  final ParameterElement element;

  AnalyzerParameterDeclaration(this.element);

  @override
  String get name => element.name;

  @override
  bool get required => element.isRequiredPositional || element.isRequiredNamed;

  @override
  TypeDeclaration get type =>
      AnalyzerTypeDeclaration(element.type.element! as TypeDefiningElement,
          originalReference: element.type);
}

class AnalyzerParameterDefinition extends AnalyzerParameterDeclaration
    implements ParameterDefinition {
  AnalyzerParameterDefinition(ParameterElement element) : super(element);

  @override
  TypeDefinition get type =>
      AnalyzerTypeDefinition(element.type.element! as TypeDefiningElement,
          originalReference: element.type);
}

class AnalyzerTypeParameterDeclaration implements TypeParameterDeclaration {
  final TypeParameterElement element;

  AnalyzerTypeParameterDeclaration(this.element);

  @override
  TypeDeclaration? get bounds => element.bound == null
      ? null
      : AnalyzerTypeDeclaration(element.bound!.element! as TypeDefiningElement,
          originalReference: element.bound);

  @override
  String get name => element.name;
}

class AnalyzerTypeParameterDefinition extends AnalyzerTypeParameterDeclaration
    implements TypeParameterDefinition {
  AnalyzerTypeParameterDefinition(TypeParameterElement element)
      : super(element);

  @override
  TypeDefinition? get bounds => element.bound == null
      ? null
      : AnalyzerTypeDefinition(element.bound!.element! as TypeDefiningElement,
          originalReference: element.bound);
}

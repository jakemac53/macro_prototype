import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../code.dart';
import '../macro.dart';

class _AnalyzerTypeDefinition implements TypeDefinition {
  final TypeDefiningElement element;
  final DartType? originalReference;

  _AnalyzerTypeDefinition(this.element, {this.originalReference});

  @override
  bool get isNullable =>
      originalReference?.nullabilitySuffix == NullabilitySuffix.question;

  @override
  Iterable<FieldDefinition> get fields sync* {
    var e = element;
    if (e is ClassElement) {
      for (var field in e.fields) {
        yield _AnalyzerFieldDefinition(field);
      }
    }
  }

  @override
  bool isSubtype(TypeDeclaration other) => throw UnimplementedError();

  @override
  Iterable<MethodDefinition> get methods sync* {
    var e = element;
    if (e is ClassElement) {
      for (var method in e.methods) {
        yield _AnalyzerMethodDefinition(method);
      }
    }
  }

  @override
  String get name => element.name!;

  @override
  Scope get scope => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get superinterfaces sync* {
    var e = element;
    if (e is ClassElement) {
      for (var interface in e.allSupertypes) {
        yield _AnalyzerTypeDefinition(interface.element,
            originalReference: interface);
      }
    }
  }

  @override
  Iterable<TypeDefinition> get typeArguments sync* {
    var reference = originalReference;
    if (reference is ParameterizedType) {
      for (var typeArgument in reference.typeArguments) {
        yield _AnalyzerTypeDefinition(
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
        yield _AnalyzerTypeParameterDefinition(parameter);
      }
    }
  }
}

class AnalyzerTargetClassDefinition extends _AnalyzerTypeDefinition
    implements TargetClassDefinition {
  AnalyzerTargetClassDefinition(ClassElement element) : super(element);

  @override
  Iterable<TargetFieldDefinition> get fields sync* {
    var e = element as ClassElement;
    for (var field in e.fields) {
      yield AnalyzerTargetFieldDefinition(field);
    }
  }

  @override
  Iterable<TargetMethodDefinition> get methods sync* {
    var e = element as ClassElement;
    for (var method in e.methods) {
      yield AnalyzerTargetMethodDefinition(method);
    }
  }
}

class _AnalyzerMethodDefinition implements MethodDefinition {
  final MethodElement element;

  _AnalyzerMethodDefinition(this.element);

  @override
  String get name => element.name;

  @override
  Map<String, ParameterDefinition> get namedParameters => {
        for (var param in element.parameters)
          if (param.isNamed) param.name: _AnalyzerParameterDefinition(param),
      };

  @override
  Iterable<ParameterDefinition> get positionalParameters sync* {
    for (var param in element.parameters) {
      if (!param.isPositional) continue;
      yield _AnalyzerParameterDefinition(param);
    }
  }

  @override
  TypeDefinition get returnType => _AnalyzerTypeDefinition(
      element.returnType.element! as TypeDefiningElement,
      originalReference: element.returnType);

  @override
  Iterable<TypeParameterDefinition> get typeParameters sync* {
    for (var typeParam in element.typeParameters) {
      yield _AnalyzerTypeParameterDefinition(typeParam);
    }
  }
}

class AnalyzerTargetMethodDefinition extends _AnalyzerMethodDefinition
    implements TargetMethodDefinition {
  AnalyzerTargetMethodDefinition(MethodElement element) : super(element);

  @override
  void implement(Code body) => throw UnimplementedError();
}

class _AnalyzerFieldDefinition implements FieldDefinition {
  final FieldElement element;

  _AnalyzerFieldDefinition(this.element);

  @override
  String get name => element.name;

  @override
  TypeDefinition get type =>
      _AnalyzerTypeDefinition(element.type.element! as TypeDefiningElement,
          originalReference: element.type);
}

class AnalyzerTargetFieldDefinition extends _AnalyzerFieldDefinition
    implements TargetFieldDefinition {
  AnalyzerTargetFieldDefinition(FieldElement element) : super(element);

  @override
  void withInitializer(Code body) => throw UnimplementedError();

  @override
  void withGetterSetterPair(Code getter, Code setter, {Code? privateField}) =>
      throw UnimplementedError();
}

class _AnalyzerParameterDefinition implements ParameterDefinition {
  final ParameterElement element;

  _AnalyzerParameterDefinition(this.element);

  @override
  String get name => element.name;

  @override
  bool get required => element.isRequiredPositional || element.isRequiredNamed;

  @override
  TypeDefinition get type =>
      _AnalyzerTypeDefinition(element.type.element! as TypeDefiningElement,
          originalReference: element.type);
}

class _AnalyzerTypeParameterDefinition implements TypeParameterDefinition {
  final TypeParameterElement element;

  _AnalyzerTypeParameterDefinition(this.element);

  @override
  TypeDefinition? get bounds => element.bound == null
      ? null
      : _AnalyzerTypeDefinition(element.bound!.element! as TypeDefiningElement,
          originalReference: element.bound);

  @override
  String get name => element.name;
}

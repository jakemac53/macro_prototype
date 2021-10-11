import 'package:isolate_experiments/protocol.dart';

import 'package:analyzer/dart/element/element.dart' as analyzer;
import 'package:analyzer/dart/element/nullability_suffix.dart' as analyzer;
import 'package:analyzer/dart/element/type.dart' as analyzer;
import 'package:macro_builder/definition.dart';
import 'package:meta/meta.dart';

T deserializeDeclaration<T extends Serializable>(Map<String, Object?> json) {
  switch (json['serializedType']) {
    case 'SerializableTypeDefinition':
      return SerializableTypeDefinition.fromJson(json) as T;
    case 'SerializableTypeParameterDefinition':
      return SerializableTypeParameterDefinition.fromJson(json) as T;
    case 'SerializableClassDefinition':
      return SerializableClassDefinition.fromJson(json) as T;
    case 'SerializableFunctionDefinition':
      return SerializableFunctionDefinition.fromJson(json) as T;
    case 'SerializableMethodDefinition':
      return SerializableMethodDefinition.fromJson(json) as T;
    case 'SerializableConstructorDefinition':
      return SerializableConstructorDefinition.fromJson(json) as T;
    case 'SerializableFieldDefinition':
      return SerializableFieldDefinition.fromJson(json) as T;
    case 'SerializableParameterDefinition':
      return SerializableParameterDefinition.fromJson(json) as T;
    case 'VoidTypeDefinition':
      return VoidTypeDefinition() as T;
    case 'DynamicTypeDefinition':
      return DynamicTypeDefinition() as T;
    default:
      throw StateError(
          'Unrecognized type to deserialize ${json['serializedType']}');
  }
}

TypeReferenceDescriptor _typeDescriptorForType(analyzer.DartType type) {
  if (type.isVoid) return TypeReferenceDescriptor('dart:core', 'void');
  if (type.isDynamic) return TypeReferenceDescriptor('dart:core', 'dynamic');
  if (type.element is! analyzer.TypeDefiningElement) {
    throw StateError(
        'Type has no element or is not a TypeDefiningElement: $type');
  }
  return _typeDescriptorForElement(
      type.element as analyzer.TypeDefiningElement, type);
}

TypeReferenceDescriptor _typeDescriptorForElement(
    analyzer.TypeDefiningElement type,
    [analyzer.DartType? originalReference]) {
  var source = type.source;
  if (source == null) throw StateError('Empty source for $type');
  return TypeReferenceDescriptor(source.uri.toString(), type.name!,
      typeArguments: [
        if (originalReference is analyzer.ParameterizedType)
          for (var typeArgument in originalReference.typeArguments)
            _typeDescriptorForType(typeArgument),
      ]);
}

class _SerializableBase implements Serializable {
  final Map<String, Object?> json;

  _SerializableBase(this.json) {
    json.putIfAbsent('serializedType', () => this.runtimeType.toString());
  }

  @override
  @mustCallSuper
  Map<String, Object?> toJson() => json;
}

class SerializableTypeDefinition extends _SerializableBase
    implements TypeDefinition {
  SerializableTypeDefinition.fromJson(Map<String, Object?> json) : super(json);

  SerializableTypeDefinition.fromElement(analyzer.TypeDefiningElement element,
      {required analyzer.DartType originalReference,
      Map<String, Object?>? parentJson})
      : super(() {
          final json = parentJson ?? <String, Object?>{};
          final name = element.name!;
          final isNullable = originalReference.nullabilitySuffix ==
              analyzer.NullabilitySuffix.question;

          json['isNullable'] = isNullable;
          json['name'] = name;
          json['typeArguments'] = [
            if (originalReference is analyzer.ParameterizedType)
              for (var typeArgument in originalReference.typeArguments)
                _typeDescriptorForType(typeArgument).toJson(),
          ];
          json['typeParameters'] = [
            if (originalReference is analyzer.ParameterizedType)
              if (element is analyzer.ClassElement)
                for (var typeArgument in element.typeParameters)
                  _typeDescriptorForElement(typeArgument).toJson(),
          ];
          json['reference'] = '$name${isNullable ? '?' : ''}';

          return json;
        }());

  @override
  bool get isAbstract => json['isAbstract'] as bool;

  @override
  bool get isExternal => json['isExternal'] as bool;

  @override
  bool get isNullable => json['isNullable'] as bool;

  @override
  bool isSubtype(TypeDeclaration other) => throw UnimplementedError();

  @override
  String get name => json['name'] as String;

  @override
  Code get reference => throw UnimplementedError();

  @override
  Scope get scope => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get typeArguments => [
        for (var argumentJson in json['typeArguments'] as List)
          reflectType<SerializableTypeDefinition>(ReflectTypeRequest(
                  TypeReferenceDescriptor.fromJson(
                      argumentJson as Map<String, Object?>)))
              .declaration,
      ];

  @override
  Iterable<TypeParameterDefinition> get typeParameters => [
        for (var parameterJson in json['typeParameters'] as List)
          reflectType<SerializableTypeParameterDefinition>(ReflectTypeRequest(
                  TypeReferenceDescriptor.fromJson(
                      parameterJson as Map<String, Object?>)))
              .declaration,
      ];
}

class SerializableTypeParameterDefinition extends _SerializableBase
    implements TypeParameterDefinition {
  SerializableTypeParameterDefinition.fromJson(Map<String, Object?> json)
      : super(json);

  factory SerializableTypeParameterDefinition.fromElement(
      analyzer.TypeParameterElement element) {
    final name = element.name;

    return SerializableTypeParameterDefinition.fromJson({
      'name': name,
      'bounds': element.bound == null
          ? null
          : SerializableTypeDefinition.fromElement(
                  element.bound!.element as analyzer.TypeDefiningElement,
                  originalReference: element.bound!)
              .toJson(),
    });
  }

  @override
  TypeDefinition? get bounds => json['bounds'] != null
      ? deserializeDeclaration<SerializableTypeDefinition>(
          json['bounds'] as Map<String, Object?>)
      : null;

  @override
  String get name => json['name'] as String;
}

class SerializableClassDefinition extends SerializableTypeDefinition
    implements ClassDefinition {
  SerializableClassDefinition.fromJson(Map<String, Object?> json)
      : super.fromJson(json);

  SerializableClassDefinition.fromElement(analyzer.ClassElement element,
      {required analyzer.DartType originalReference})
      : super.fromElement(element, originalReference: originalReference,
            parentJson: () {
          var json = <String, Object?>{};
          json['constructors'] = [
            for (var constructor in element.constructors)
              if (!constructor.isSynthetic)
                SerializableConstructorDefinition.fromElement(constructor)
                    .toJson(),
          ];
          json['methods'] = [
            for (var method in element.methods)
              if (!method.isSynthetic)
                SerializableMethodDefinition.fromElement(method).toJson(),
          ];
          json['fields'] = [
            for (var field in element.fields)
              if (!field.isSynthetic)
                SerializableFieldDefinition.fromElement(field).toJson(),
          ];
          var e = element;
          if (e is analyzer.ClassElement && !e.isDartCoreObject) {
            var superType = e.supertype!;
            json['superclass'] = _typeDescriptorForType(superType).toJson();
          }
          json['supertypes'] = [
            if (e is analyzer.ClassElement)
              for (var interface in e.allSupertypes)
                _typeDescriptorForType(interface).toJson(),
          ];

          return json;
        }());

  @override
  Iterable<MethodDefinition> get constructors => [
        for (var constructorJson in json['constructors'] as List)
          deserializeDeclaration(constructorJson as Map<String, Object?>),
      ];

  @override
  Iterable<MethodDefinition> get methods => [
        for (var methodJson in json['methods'] as List)
          deserializeDeclaration(methodJson as Map<String, Object?>),
      ];

  @override
  Iterable<FieldDefinition> get fields => [
        for (var fieldJson in json['fields'] as List)
          deserializeDeclaration(fieldJson as Map<String, Object?>),
      ];

  @override
  ClassDefinition? get superclass => json['superclass'] != null
      ? deserializeDeclaration(json['superclass'] as Map<String, Object?>)
      : null;

  @override
  Iterable<TypeDeclaration> get superinterfaces => [
        for (var interfaceJson in json['superinterfaces'] as List)
          deserializeDeclaration(interfaceJson as Map<String, Object?>),
      ];
}

class SerializableFunctionDefinition extends _SerializableBase
    implements FunctionDefinition {
  SerializableFunctionDefinition.fromJson(Map<String, Object?> json)
      : super(json);

  SerializableFunctionDefinition.fromElement(analyzer.ExecutableElement element,
      {Map<String, Object?>? parentJson})
      : super(() {
          var e = element;
          var json = parentJson ?? <String, Object?>{};
          json['isAbstract'] = e.isAbstract;
          json['isExternal'] = e.isExternal;
          json['isGetter'] =
              e is analyzer.PropertyAccessorElement && e.isGetter;
          json['isSetter'] =
              e is analyzer.PropertyAccessorElement && e.isSetter;
          json['name'] = e.name;
          json['namedParameters'] = {
            for (var param in element.parameters)
              if (param.isNamed)
                SerializableParameterDefinition.fromElement(param).toJson(),
          };
          json['positionalParameters'] = [
            for (var param in element.parameters)
              if (param.isPositional)
                SerializableParameterDefinition.fromElement(param).toJson(),
          ];
          json['typeParameters'] = [
            if (e.returnType is analyzer.ParameterizedType)
              for (var typeArgument in e.typeParameters)
                _typeDescriptorForElement(typeArgument).toJson(),
          ];
          json['returnType'] = _typeDescriptorForType(e.returnType).toJson();
          return json;
        }());

  @override
  bool get isAbstract => json['isAbstract'] as bool;

  @override
  bool get isExternal => json['isExternal'] as bool;

  @override
  bool get isGetter => json['isGetter'] as bool;

  @override
  bool get isSetter => json['isSetter'] as bool;

  @override
  String get name => json['name'] as String;

  @override
  Map<String, ParameterDefinition> get namedParameters => {
        for (var paramJson in json['namedParameters'] as List)
          paramJson['name'] as String:
              deserializeDeclaration(paramJson as Map<String, Object?>),
      };

  @override
  Iterable<ParameterDefinition> get positionalParameters => {
        for (var paramJson in json['positionalParameters'] as List)
          deserializeDeclaration(paramJson as Map<String, Object?>),
      };

  @override
  TypeDefinition get returnType => reflectType<SerializableTypeDefinition>(
          ReflectTypeRequest(TypeReferenceDescriptor.fromJson(
              json['returnType'] as Map<String, Object?>)))
      .declaration;

  @override
  Iterable<TypeParameterDefinition> get typeParameters => [
        for (var parameterJson in json['typeParameters'] as List)
          reflectType<SerializableTypeParameterDefinition>(ReflectTypeRequest(
                  TypeReferenceDescriptor.fromJson(
                      parameterJson as Map<String, Object?>)))
              .declaration,
      ];
}

class SerializableMethodDefinition extends SerializableFunctionDefinition
    implements MethodDefinition {
  SerializableMethodDefinition.fromJson(Map<String, Object?> json)
      : super.fromJson(json);

  SerializableMethodDefinition.fromElement(analyzer.ExecutableElement element,
      {Map<String, Object?>? parentJson})
      : super.fromElement(element, parentJson: () {
          var json = parentJson ?? <String, Object?>{};
          var clazz = element.enclosingElement as analyzer.ClassElement;
          json['definingClass'] =
              _typeDescriptorForType(clazz.thisType).toJson();
          return json;
        }());

  @override
  ClassDeclaration get definingClass =>
      reflectType<SerializableClassDefinition>(ReflectTypeRequest(
              TypeReferenceDescriptor.fromJson(
                  json['definingClass'] as Map<String, Object?>)))
          .declaration;
}

class SerializableConstructorDefinition extends SerializableMethodDefinition
    implements ConstructorDefinition {
  SerializableConstructorDefinition.fromJson(Map<String, Object?> json)
      : super.fromJson(json);

  SerializableConstructorDefinition.fromElement(
      analyzer.ConstructorElement element,
      {Map<String, Object?>? parentJson})
      : super.fromElement(element, parentJson: () {
          var json = parentJson ?? <String, Object?>{};
          json['isFactory'] = element.isFactory;
          return json;
        }());

  @override
  bool get isFactory => json['isFactory'] as bool;
}

class SerializableFieldDefinition extends _SerializableBase
    implements FieldDefinition {
  SerializableFieldDefinition.fromJson(Map<String, Object?> json) : super(json);

  SerializableFieldDefinition.fromElement(analyzer.FieldElement element)
      : super(() {
          var json = <String, Object?>{};
          var clazz = element.enclosingElement as analyzer.ClassElement;
          json['definingClass'] =
              _typeDescriptorForType(clazz.thisType).toJson();
          json['isAbstract'] = element.isAbstract;
          json['isExternal'] = element.isExternal;
          json['name'] = element.name;
          json['type'] = _typeDescriptorForType(element.type).toJson();
          return json;
        }());

  @override
  ClassDeclaration get definingClass =>
      reflectType<SerializableClassDefinition>(ReflectTypeRequest(
              TypeReferenceDescriptor.fromJson(
                  json['definingClass'] as Map<String, Object?>)))
          .declaration;

  @override
  bool get isAbstract => json['isAbstract'] as bool;

  @override
  bool get isExternal => json['isExternal'] as bool;

  @override
  String get name => json['name'] as String;

  @override
  TypeDefinition get type => reflectType<SerializableClassDefinition>(
          ReflectTypeRequest(TypeReferenceDescriptor.fromJson(
              json['type'] as Map<String, Object?>)))
      .declaration;
}

class SerializableParameterDefinition extends _SerializableBase
    implements ParameterDefinition {
  SerializableParameterDefinition.fromJson(Map<String, Object?> json)
      : super(json);

  SerializableParameterDefinition.fromElement(analyzer.ParameterElement element)
      : super(() {
          var json = <String, Object?>{};
          json['name'] = element.name;
          json['required'] =
              element.isRequiredPositional || element.isRequiredNamed;
          json['type'] = _typeDescriptorForType(element.type).toJson();
          return json;
        }());

  @override
  String get name => json['name'] as String;

  @override
  bool get required => json['required'] as bool;

  @override
  TypeDefinition get type => reflectType<SerializableClassDefinition>(
          ReflectTypeRequest(TypeReferenceDescriptor.fromJson(
              json['type'] as Map<String, Object?>)))
      .declaration;
}

class VoidTypeDefinition extends _SerializableBase implements TypeDefinition {
  VoidTypeDefinition._() : super(<String, Object?>{});

  factory VoidTypeDefinition() => _instance;

  static final _instance = VoidTypeDefinition._();

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
  Scope get scope => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get typeArguments => const [];

  @override
  Iterable<TypeParameterDefinition> get typeParameters => const [];
}

class DynamicTypeDefinition extends _SerializableBase
    implements TypeDefinition {
  DynamicTypeDefinition._() : super(<String, Object?>{});

  factory DynamicTypeDefinition() => _instance;

  static final _instance = DynamicTypeDefinition._();

  @override
  bool get isAbstract => false;

  @override
  bool get isExternal => false;

  @override
  bool get isNullable => false;

  @override
  bool isSubtype(TypeDeclaration other) => false;

  @override
  String get name => 'dynamic';

  @override
  Code get reference => TypeAnnotation('dynamic');

  @override
  Scope get scope => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get typeArguments => const [];

  @override
  Iterable<TypeParameterDefinition> get typeParameters => const [];
}

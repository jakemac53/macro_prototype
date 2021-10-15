import 'package:isolate_experiments/protocol.dart';

import 'package:analyzer/dart/element/element.dart' as analyzer;
import 'package:analyzer/dart/element/nullability_suffix.dart' as analyzer;
import 'package:analyzer/dart/element/type.dart' as analyzer;
import 'package:macro_builder/definition.dart';
import 'package:messagepack/messagepack.dart';
import 'package:meta/meta.dart';

abstract class Packable {
  @mustCallSuper
  void pack(Packer packer);
}

void packList(List<Packable> items, Packer packer) {
  packer.packListLength(items.length);
  for (var item in items) {
    item.pack(packer);
  }
}

List<T> unpackList<T>(T Function(Unpacker) unpack, Unpacker unpacker) {
  var length = unpacker.unpackListLength();
  return [
    for (var i = 0; i < length; i++) unpack(unpacker),
  ];
}

void packNullable(Packable? packable, Packer packer) {
  if (packable == null) {
    packer.packBool(null);
  } else {
    packer.packBool(true);
    packable.pack(packer);
  }
}

T? unpackNullable<T>(T Function(Unpacker) unpack, Unpacker unpacker) {
  if (unpacker.unpackBool() == null) return null;
  return unpack(unpacker);
}

void packDeclaration(Packable packable, Packer packer) {
  packer.packString(packable.runtimeType.toString());
  packable.pack(packer);
}

T unpackDeclaration<T extends Packable>(Unpacker unpacker) {
  var type = unpacker.unpackString()!;
  switch (type) {
    case 'PackableTypeDefinition':
      return PackableTypeDefinition.unpack(unpacker) as T;
    case 'PackableTypeParameterDefinition':
      return PackableTypeParameterDefinition.unpack(unpacker) as T;
    case 'PackableClassDefinition':
      return PackableClassDefinition.unpack(unpacker) as T;
    case 'PackableFunctionDefinition':
      return PackableFunctionDefinition.unpack(unpacker) as T;
    case 'PackableMethodDefinition':
      return PackableMethodDefinition.unpack(unpacker) as T;
    case 'PackableConstructorDefinition':
      return PackableConstructorDefinition.unpack(unpacker) as T;
    case 'PackableFieldDefinition':
      return PackableFieldDefinition.unpack(unpacker) as T;
    case 'PackableParameterDefinition':
      return PackableParameterDefinition.unpack(unpacker) as T;
    case 'VoidTypeDefinition':
      return VoidTypeDefinition() as T;
    case 'DynamicTypeDefinition':
      return DynamicTypeDefinition() as T;
    default:
      throw StateError('Unrecognized type to deserialize $type');
  }
}

TypeReferenceDescriptor _typeDescriptorForType(analyzer.DartType type) {
  if (type.isVoid) return TypeReferenceDescriptor('dart:core', 'void', false);
  if (type.isDynamic) {
    return TypeReferenceDescriptor('dart:core', 'dynamic', false);
  }
  var element = type.element;
  if (element is analyzer.TypeDefiningElement) {
    return _typeDescriptorForElement(element, type);
  } else if (type is analyzer.FunctionType) {
    return TypeReferenceDescriptor(
        element == null ? 'unknown' : element.source!.uri.toString(),
        type.getDisplayString(withNullability: true),
        type.nullabilitySuffix == analyzer.NullabilitySuffix.question);
  } else {
    throw StateError(
        'Type could not be serialized: ${type.runtimeType} : $type ');
  }
}

TypeReferenceDescriptor _typeDescriptorForElement(
    analyzer.TypeDefiningElement type,
    [analyzer.DartType? originalReference]) {
  var source = type.source;
  if (source == null) throw StateError('Empty source for $type');
  return TypeReferenceDescriptor(
      source.uri.toString(),
      type.name!,
      originalReference?.nullabilitySuffix ==
          analyzer.NullabilitySuffix.question,
      typeArguments: [
        if (originalReference is analyzer.ParameterizedType)
          for (var typeArgument in originalReference.typeArguments)
            _typeDescriptorForType(typeArgument),
      ]);
}

class PackableTypeDefinition implements TypeDefinition, Packable {
  @override
  final bool isAbstract;

  @override
  final bool isExternal;

  @override
  final bool isNullable;

  @override
  final String name;

  final List<TypeReferenceDescriptor> typeArgumentDescriptors;

  @override
  final List<PackableTypeParameterDefinition> typeParameters;

  PackableTypeDefinition.unpack(Unpacker unpacker)
      : isAbstract = unpacker.unpackBool()!,
        isExternal = unpacker.unpackBool()!,
        isNullable = unpacker.unpackBool()!,
        name = unpacker.unpackString()!,
        typeArgumentDescriptors = unpackList(
            (unpacker) => TypeReferenceDescriptor.unpack(unpacker), unpacker),
        typeParameters = unpackList(
            (unpacker) => PackableTypeParameterDefinition.unpack(unpacker),
            unpacker);

  PackableTypeDefinition.fromElement(analyzer.TypeDefiningElement element,
      {required analyzer.DartType originalReference})
      : isAbstract =
            (element is analyzer.ClassElement) ? element.isAbstract : false,
        isExternal = false,
        isNullable = originalReference.nullabilitySuffix ==
            analyzer.NullabilitySuffix.question,
        name = element.name!,
        typeArgumentDescriptors = [
          if (originalReference is analyzer.ParameterizedType)
            for (var typeArgument in originalReference.typeArguments)
              _typeDescriptorForType(typeArgument)
        ],
        typeParameters = [
          if (originalReference is analyzer.ParameterizedType)
            if (element is analyzer.ClassElement)
              for (var typeArgument in element.typeParameters)
                PackableTypeParameterDefinition.fromElement(typeArgument)
        ];

  @override
  void pack(Packer packer) {
    packer
      ..packBool(isAbstract)
      ..packBool(isExternal)
      ..packBool(isNullable)
      ..packString(name);
    packList(typeArgumentDescriptors, packer);
    packList(typeParameters, packer);
  }

  @override
  Code get reference => TypeAnnotation('$name${isNullable ? '?' : ''}');

  @override
  Scope get scope => throw UnimplementedError();

  @override
  bool isSubtype(TypeDeclaration other) => throw UnimplementedError();

  @override
  Iterable<TypeDefinition> get typeArguments =>
      typeArgumentDescriptors.map((typeDescriptor) {
        var request = ReflectTypeRequest(typeDescriptor);
        var response = reflectType(request);
        return response.declaration as TypeDefinition;
      });
}

class PackableTypeParameterDefinition
    implements TypeParameterDefinition, Packable {
  final TypeReferenceDescriptor? boundsDescriptor;

  @override
  final String name;

  PackableTypeParameterDefinition.unpack(Unpacker unpacker)
      : name = unpacker.unpackString()!,
        boundsDescriptor = unpackNullable(
            (Unpacker unpacker) => TypeReferenceDescriptor.unpack(unpacker),
            unpacker);

  PackableTypeParameterDefinition.fromElement(
      analyzer.TypeParameterElement element)
      : boundsDescriptor = element.bound == null
            ? null
            : _typeDescriptorForType(element.bound!),
        name = element.name;

  @override
  void pack(Packer packer) {
    packer.packString(name);
    packNullable(boundsDescriptor, packer);
  }

  @override
  TypeDefinition? get bounds => boundsDescriptor == null
      ? null
      : reflectType(ReflectTypeRequest(boundsDescriptor!)).declaration
          as TypeDefinition;
}

class PackableClassDefinition extends PackableTypeDefinition
    implements ClassDefinition {
  @override
  final List<PackableConstructorDefinition> constructors;

  @override
  final List<PackableMethodDefinition> methods;

  @override
  final List<PackableFieldDefinition> fields;

  final TypeReferenceDescriptor? superclassDescriptor;

  final List<TypeReferenceDescriptor> superinterfaceDescriptors;

  PackableClassDefinition.unpack(Unpacker unpacker)
      : constructors = unpackList(
            (unpacker) => PackableConstructorDefinition.unpack(unpacker),
            unpacker),
        methods = unpackList(
            (unpacker) => PackableMethodDefinition.unpack(unpacker), unpacker),
        fields = unpackList(
            (unpacker) => PackableFieldDefinition.unpack(unpacker), unpacker),
        superclassDescriptor = unpackNullable(
            (unpacker) => TypeReferenceDescriptor.unpack(unpacker), unpacker),
        superinterfaceDescriptors = unpackList(
            (unpacker) => TypeReferenceDescriptor.unpack(unpacker), unpacker),
        super.unpack(unpacker);

  PackableClassDefinition.fromElement(analyzer.ClassElement element,
      {required analyzer.DartType originalReference})
      : constructors = [
          for (var constructor in element.constructors)
            if (!constructor.isSynthetic)
              PackableConstructorDefinition.fromElement(constructor),
        ],
        methods = [
          for (var method in element.methods)
            if (!method.isSynthetic)
              PackableMethodDefinition.fromElement(method),
        ],
        fields = [
          for (var field in element.fields)
            if (!field.isSynthetic) PackableFieldDefinition.fromElement(field),
        ],
        superclassDescriptor =
            element is analyzer.ClassElement && !element.isDartCoreObject
                ? _typeDescriptorForType(element.supertype!)
                : null,
        superinterfaceDescriptors = [
          if (element is analyzer.ClassElement)
            for (var interface in element.allSupertypes)
              _typeDescriptorForType(interface),
        ],
        super.fromElement(element, originalReference: originalReference);

  @override
  void pack(Packer packer) {
    packList(constructors, packer);
    packList(methods, packer);
    packList(fields, packer);
    packNullable(superclassDescriptor, packer);
    packList(superinterfaceDescriptors, packer);
    super.pack(packer);
  }

  @override
  ClassDefinition? get superclass => superclassDescriptor == null
      ? null
      : reflectType(ReflectTypeRequest(superclassDescriptor!)).declaration
          as ClassDefinition;

  @override
  List<TypeDefinition> get superinterfaces => [
        for (var descriptor in superinterfaceDescriptors)
          reflectType(ReflectTypeRequest(descriptor)).declaration
              as TypeDefinition,
      ];
}

class PackableFunctionDefinition implements FunctionDefinition, Packable {
  @override
  final bool isAbstract;

  @override
  final bool isExternal;

  @override
  final bool isGetter;

  @override
  final bool isSetter;

  @override
  final String name;

  @override
  final Map<String, PackableParameterDefinition> namedParameters;

  @override
  final List<PackableParameterDefinition> positionalParameters;

  final TypeReferenceDescriptor returnTypeDescriptor;

  @override
  final List<PackableTypeParameterDefinition> typeParameters;

  PackableFunctionDefinition.unpack(Unpacker unpacker)
      : isAbstract = unpacker.unpackBool()!,
        isExternal = unpacker.unpackBool()!,
        isGetter = unpacker.unpackBool()!,
        isSetter = unpacker.unpackBool()!,
        name = unpacker.unpackString()!,
        namedParameters = {
          for (var param in unpackList(
              (unpacker) => PackableParameterDefinition.unpack(unpacker),
              unpacker))
            param.name: param,
        },
        positionalParameters = unpackList(
            (unpacker) => PackableParameterDefinition.unpack(unpacker),
            unpacker),
        returnTypeDescriptor = TypeReferenceDescriptor.unpack(unpacker),
        typeParameters = unpackList(
            (unpacker) => PackableTypeParameterDefinition.unpack(unpacker),
            unpacker);

  PackableFunctionDefinition.fromElement(analyzer.ExecutableElement element)
      : isAbstract = element.isAbstract,
        isExternal = element.isExternal,
        isGetter =
            element is analyzer.PropertyAccessorElement && element.isGetter,
        isSetter =
            element is analyzer.PropertyAccessorElement && element.isSetter,
        name = element.name,
        namedParameters = {
          for (var param in element.parameters)
            if (param.isNamed)
              param.name: PackableParameterDefinition.fromElement(param),
        },
        positionalParameters = [
          for (var param in element.parameters)
            if (param.isPositional)
              PackableParameterDefinition.fromElement(param),
        ],
        typeParameters = [
          if (element.returnType is analyzer.ParameterizedType)
            for (var typeArgument in element.typeParameters)
              PackableTypeParameterDefinition.fromElement(typeArgument),
        ],
        returnTypeDescriptor = _typeDescriptorForType(element.returnType);

  @override
  void pack(Packer packer) {
    packer
      ..packBool(isAbstract)
      ..packBool(isExternal)
      ..packBool(isGetter)
      ..packBool(isSetter)
      ..packString(name);
    packList(namedParameters.values.toList(), packer);
    packList(positionalParameters, packer);
    returnTypeDescriptor.pack(packer);
    packList(typeParameters, packer);
  }

  @override
  TypeDefinition get returnType =>
      reflectType(ReflectTypeRequest(returnTypeDescriptor)).declaration
          as TypeDefinition;
}

class PackableMethodDefinition extends PackableFunctionDefinition
    implements MethodDefinition {
  final TypeReferenceDescriptor definingClassDescriptor;

  PackableMethodDefinition.unpack(Unpacker unpacker)
      : definingClassDescriptor = TypeReferenceDescriptor.unpack(unpacker),
        super.unpack(unpacker);

  PackableMethodDefinition.fromElement(analyzer.ExecutableElement element,
      {Map<String, Object?>? parentJson})
      : definingClassDescriptor = _typeDescriptorForElement(
            element.enclosingElement as analyzer.ClassElement),
        super.fromElement(element);

  @override
  ClassDeclaration get definingClass =>
      reflectType(ReflectTypeRequest(definingClassDescriptor)).declaration
          as ClassDeclaration;

  @override
  void pack(Packer packer) {
    definingClassDescriptor.pack(packer);
    super.pack(packer);
  }
}

class PackableConstructorDefinition extends PackableMethodDefinition
    implements ConstructorDefinition {
  @override
  final bool isFactory;

  PackableConstructorDefinition.unpack(Unpacker unpacker)
      : isFactory = unpacker.unpackBool()!,
        super.unpack(unpacker);

  PackableConstructorDefinition.fromElement(analyzer.ConstructorElement element)
      : isFactory = element.isFactory,
        super.fromElement(element);

  @override
  void pack(Packer packer) {
    packer.packBool(isFactory);
    super.pack(packer);
  }
}

class PackableFieldDefinition implements FieldDefinition, Packable {
  final TypeReferenceDescriptor definingClassDescriptor;

  @override
  final bool isAbstract;

  @override
  final bool isExternal;

  @override
  final String name;

  final TypeReferenceDescriptor typeDescriptor;

  PackableFieldDefinition.unpack(Unpacker unpacker)
      : definingClassDescriptor = TypeReferenceDescriptor.unpack(unpacker),
        isAbstract = unpacker.unpackBool()!,
        isExternal = unpacker.unpackBool()!,
        name = unpacker.unpackString()!,
        typeDescriptor = TypeReferenceDescriptor.unpack(unpacker);

  PackableFieldDefinition.fromElement(analyzer.FieldElement element)
      : definingClassDescriptor = _typeDescriptorForElement(
            element.enclosingElement as analyzer.ClassElement),
        isAbstract = element.isAbstract,
        isExternal = element.isExternal,
        name = element.name,
        typeDescriptor = _typeDescriptorForType(element.type);

  @override
  void pack(Packer packer) {
    definingClassDescriptor.pack(packer);
    packer
      ..packBool(isAbstract)
      ..packBool(isExternal)
      ..packString(name);
    typeDescriptor.pack(packer);
  }

  @override
  ClassDeclaration get definingClass =>
      reflectType(ReflectTypeRequest(definingClassDescriptor)).declaration
          as ClassDeclaration;

  @override
  TypeDefinition get type =>
      reflectType(ReflectTypeRequest(typeDescriptor)).declaration
          as TypeDefinition;
}

class PackableParameterDefinition implements ParameterDefinition, Packable {
  @override
  final String name;

  @override
  final bool required;

  final TypeReferenceDescriptor typeDescriptor;

  PackableParameterDefinition.unpack(Unpacker unpacker)
      : name = unpacker.unpackString()!,
        required = unpacker.unpackBool()!,
        typeDescriptor = TypeReferenceDescriptor.unpack(unpacker);

  PackableParameterDefinition.fromElement(analyzer.ParameterElement element)
      : name = element.name,
        required = element.isRequiredPositional || element.isRequiredNamed,
        typeDescriptor = _typeDescriptorForType(element.type);

  @override
  void pack(Packer packer) {
    packer
      ..packString(name)
      ..packBool(required);
    typeDescriptor.pack(packer);
  }

  @override
  TypeDefinition get type =>
      reflectType(ReflectTypeRequest(typeDescriptor)).declaration
          as TypeDefinition;
}

class VoidTypeDefinition implements Packable, TypeDefinition {
  VoidTypeDefinition._();

  factory VoidTypeDefinition() => _instance;

  static final _instance = VoidTypeDefinition._();

  @override
  void pack(_) {}

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

class DynamicTypeDefinition implements Packable, TypeDefinition {
  DynamicTypeDefinition._();

  factory DynamicTypeDefinition() => _instance;

  static final _instance = DynamicTypeDefinition._();

  @override
  void pack(_) {}

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

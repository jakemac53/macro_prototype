import 'package:macro_builder/macro_builder.dart';

const jsonSerializable = _JsonMacro();

class _JsonMacro implements ClassDeclarationMacro, MethodDefinitionMacro {
  const _JsonMacro();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    builder
      ..addToClass(Declaration(
          '@jsonSerializable\nexternal Map<String, Object?> toJson();'))
      ..addToClass(Declaration('@jsonSerializable\n'
          'external ${declaration.name}.fromJson(Map<String, Object?> json);'));
  }

  @override
  void visitMethodDefinition(
      MethodDefinition definition, FunctionDefinitionBuilder builder) {
    switch (definition.name) {
      case 'fromJson':
        _defineFromJson(definition, builder);
        break;
      case 'toJson':
        _defineToJson(definition, builder);
        break;
    }
  }

  void _defineFromJson(
      MethodDefinition fromJson, FunctionDefinitionBuilder builder) {
    Code code = Fragment(' : ');
    var clazz = fromJson.definingClass;
    var fields = clazz.fields.toList();
    for (var field in fields) {
      code = Fragment(
          '$code\n ${field.name} = ${_typeFromJson(field.type, Fragment('json["${field.name}"]'))}'
          '${field != fields.last ? ',' : ''}');
    }
    // Need to call super constructors, we require they have a fromJson
    // constructor identical to one we would create, to simplify things.
    var superclass = clazz.superclass;
    if (superclass != null && superclass.name != 'Object') {
      if (!_hasFromJson(superclass)) {
        throw UnsupportedError(
            '@jsonSerializable only works if applied to all superclasses.');
      }
      code = Fragment('$code,\nsuper.fromJson(json)');
    }

    code = Fragment('$code;');
    builder.implement(code);
  }

  void _defineToJson(
      MethodDefinition toJson, FunctionDefinitionBuilder builder) {
    var clazz = toJson.definingClass;
    var allFields = <FieldDefinition>[...clazz.fields];
    var next = clazz.superclass;
    while (next is ClassDefinition && next.name != 'Object') {
      allFields.addAll(next.fields);
      next = next.superclass;
    }
    var entries = <Code>[];
    for (var field in allFields) {
      entries.add(Fragment(
          '  "${field.name}": ${_typeToJson(field.type, Fragment(field.name))}, '));
    }
    var body =
        FunctionBody.fromParts(['=> <String, Object?>{', ...entries, '};']);
    builder.implement(body);
  }

  Code _typeFromJson(TypeDefinition type, Code jsonReference) {
    if (type.name == 'List') {
      var typeArgFromJson =
          _typeFromJson(type.typeArguments.first, Fragment('e'));
      return Fragment(
          '[for (var e in $jsonReference as List<Object?>) $typeArgFromJson]');
    }
    if (_hasFromJson(type)) {
      return Fragment(
          '${type.name}.fromJson($jsonReference as Map<String, Object?>)');
    }
    return Fragment('$jsonReference as ${type.toCode()}');
  }

  Code _typeToJson(TypeDefinition type, Code instanceReference) {
    if (type.name == 'List') {
      var typeArgToJson = _typeToJson(type.typeArguments.first, Fragment('e'));
      return Fragment('[for (var e in $instanceReference) $typeArgToJson]');
    }
    var hasCompatibleToJson = type is ClassDefinition &&
        type.methods.any((element) =>
            element.name == 'toJson' &&
            element.returnType.name == 'Map' &&
            element.returnType.typeArguments.first.name == 'String');
    return Fragment(
        '$instanceReference${hasCompatibleToJson ? '.toJson()' : ''}');
  }

  bool _hasFromJson(TypeDefinition definition) =>
      definition is ClassDefinition &&
      definition.constructors.any((constructor) =>
          constructor.name == 'fromJson' &&
          constructor.positionalParameters.length == 1 &&
          constructor.positionalParameters.first.type.name == 'Map' &&
          constructor
                  .positionalParameters.first.type.typeArguments.first.name ==
              'String');
}

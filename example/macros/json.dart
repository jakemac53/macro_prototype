import 'package:macro_builder/macro_builder.dart';

const jsonSerializable = _JsonMacro();

class _JsonMacro implements ClassDeclarationMacro, ClassDefinitionMacro {
  const _JsonMacro();

  void declare(TargetClassDeclaration declaration) {
    declaration
      ..addToClass(Code('external Map<String, Object?> toJson();'))
      ..addToClass(Code(
          'external ${declaration.name}.fromJson(Map<String, Object?> json);'));
  }

  void define(TargetClassDefinition definition) {
    _defineFromJson(definition);
    _defineToJson(definition);
  }

  void _defineFromJson(TargetClassDefinition definition) {
    var fromJson =
        definition.constructors.firstWhere((m) => m.name == 'fromJson');
    var code = Code(' : ');
    var fields = definition.fields.toList();
    for (var field in fields) {
      code = Code(
          '$code\n ${field.name} = ${_typeFromJson(field.type, Code('json["${field.name}"]'))}'
          '${field != fields.last ? ',' : ''}');
    }
    // Need to call super constructors, we require they have a fromJson
    // constructor identical to one we would create, to simplify things.
    var superclass = definition.superclass;
    if (superclass != null && superclass.name != 'Object') {
      if (!_hasFromJson(superclass)) {
        throw UnsupportedError(
            '@jsonSerializable only works if applied to all superclasses.');
      }
      code = Code('$code,\nsuper.fromJson(json)');
    }

    code = Code('$code;');
    fromJson.implement(code);
  }

  void _defineToJson(TargetClassDefinition definition) {
    var toJsonMethod = definition.methods.firstWhere((m) => m.name == 'toJson');
    var code = Code('=> <String, Object?>{\n');
    var allFields = <FieldDefinition>[...definition.fields];
    var next = definition.superclass;
    while (next != null && next.name != 'Object') {
      allFields.addAll(next.fields);
      next = next.superclass;
    }
    for (var field in allFields) {
      code = Code(
          '$code  "${field.name}": ${_typeToJson(field.type, Code(field.name))},\n');
    }
    code = Code('$code};');
    toJsonMethod.implement(code);
  }

  Code _typeFromJson(TypeDefinition type, Code jsonReference) {
    if (type.name == 'List') {
      var typeArgFromJson = _typeFromJson(type.typeArguments.first, Code('e'));
      return Code(
          '[for (var e in $jsonReference as List<Object?>) $typeArgFromJson]');
    }
    if (_hasFromJson(type)) {
      return Code(
          '${type.name}.fromJson($jsonReference as Map<String, Object?>)');
    }
    return Code('$jsonReference as ${type.toCode()}');
  }

  Code _typeToJson(TypeDefinition type, Code instanceReference) {
    if (type.name == 'List') {
      var typeArgToJson = _typeToJson(type.typeArguments.first, Code('e'));
      return Code('[for (var e in $instanceReference) $typeArgToJson]');
    }
    var hasCompatibleToJson = type.methods.any((element) =>
        element.name == 'toJson' &&
        element.returnType.name == 'Map' &&
        element.returnType.typeArguments.first.name == 'String');
    return Code('$instanceReference${hasCompatibleToJson ? '.toJson()' : ''}');
  }

  bool _hasFromJson(TypeDefinition definition) =>
      definition.constructors.any((constructor) =>
          constructor.name == 'fromJson' &&
          constructor.positionalParameters.length == 1 &&
          constructor.positionalParameters.first.type.name == 'Map' &&
          constructor
                  .positionalParameters.first.type.typeArguments.first.name ==
              'String');
}

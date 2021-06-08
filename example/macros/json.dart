import 'package:collection/collection.dart';

import 'package:macro_builder/macro_builder.dart';

const toJson = _ToJsonMacro();

class _ToJsonMacro implements ClassDeclarationMacro, ClassDefinitionMacro {
  const _ToJsonMacro();

  void declare(TargetClassDeclaration declaration) {
    declaration.addToClass(Code('external Map<String, Object?> toJson();'));
  }

  void define(TargetClassDefinition definition) {
    var toJsonMethod = definition.methods.firstWhere((m) => m.name == 'toJson');
    var code = Code('=> <String, Object?>{\n');
    var allFields = [
      for (var interface in definition.superinterfaces)
        if (interface.name != 'Object') ...interface.fields,
      ...definition.fields,
    ];
    for (var field in allFields) {
      code = Code(
          '$code  "${field.name}": ${_typeToJson(field.type, Code(field.name))},\n');
    }
    code = Code('$code};');
    toJsonMethod.implement(code);
  }

  // TODO: better checks here with real types and `isSubtypeOf`.
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
}

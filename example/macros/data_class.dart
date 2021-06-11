import 'package:collection/collection.dart';
import 'package:macro_builder/macro_builder.dart';

const dataClass = const _DataClass();

class _DataClass implements ClassDeclarationMacro {
  const _DataClass();

  void declare(TargetClassDeclaration declaration) {
    autoConstructor.declare(declaration);
  }
}

const autoConstructor = const _AutoConstructor();

class _AutoConstructor implements ClassDeclarationMacro {
  const _AutoConstructor();

  void declare(TargetClassDeclaration declaration) {
    if (declaration.constructors.any((c) => c.name == '')) {
      throw ArgumentError(
          'Cannot generate a constructor because one already exists');
    }
    var code = Code('${declaration.name}({');
    for (var field in declaration.fields) {
      var requiredKeyword = field.type.isNullable ? '' : 'required ';
      code = Code('$code\n${requiredKeyword}this.${field.name},');
    }
    var superclass = declaration.superclass;
    MethodDeclaration? superconstructor;
    if (superclass != null) {
      var superconstructor =
          superclass.constructors.firstWhereOrNull((c) => c.name == '');
      if (superconstructor == null) {
        throw ArgumentError(
            'Super class $superclass of $declaration does not have an unnamed '
            'constructor');
      }
      // TODO: copy default values if present for super constructor params,
      // that would require access to those.
      for (var param in superconstructor.positionalParameters) {
        var requiredKeyword = param.type.isNullable ? '' : 'required ';
        code = Code(
            '$code\n$requiredKeyword${param.type.toCode()} ${param.name},');
      }
      for (var param in superconstructor.namedParameters.values) {
        var requiredKeyword = param.required ? '' : 'required ';
        code = Code(
            '$code\n$requiredKeyword${param.type.toCode()} ${param.name},');
      }
    }
    code = Code('$code\n})');
    if (superconstructor != null) {
      code = Code('$code : super(');
      for (var param in superconstructor.positionalParameters) {
        code = Code('$code\n${param.name},');
      }
      if (superconstructor.namedParameters.isNotEmpty) {
        code = Code('$code {');
        for (var param in superconstructor.namedParameters.values) {
          code = Code('$code\n${param.name}: ${param.name},');
        }
        code = Code('$code\n}');
      }
      code = Code('$code)');
    }
    code = Code('$code;');
    declaration.addToClass(code);
  }
}

const copyWith = const _CopyWith();

class _CopyWith implements ClassDeclarationMacro {
  const _CopyWith();

  void declare(TargetClassDeclaration declaration) {
    if (declaration.methods.any((c) => c.name == 'copyWith')) {
      throw ArgumentError(
          'Cannot generate a copyWith method because one already exists');
    }
  }
}

import 'package:collection/collection.dart';
import 'package:macro_builder/definition.dart';

const dataClass = DataClass();

class DataClass implements ClassDeclarationMacro {
  const DataClass();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    autoConstructor.visitClassDeclaration(declaration, builder);
    copyWith.visitClassDeclaration(declaration, builder);
    hashCode.visitClassDeclaration(declaration, builder);
    equality.visitClassDeclaration(declaration, builder);
    toString.visitClassDeclaration(declaration, builder);
  }
}

const autoConstructor = AutoConstructor();

class AutoConstructor implements ClassDeclarationMacro {
  const AutoConstructor();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    if (declaration.constructors.any((c) => c.name == '')) {
      throw ArgumentError(
          'Cannot generate a constructor because one already exists');
    }
    Code code = Fragment('${declaration.name}({');
    for (var field in declaration.fields) {
      var requiredKeyword = field.type.isNullable ? '' : 'required ';
      code = Fragment('$code\n${requiredKeyword}this.${field.name},');
    }
    var superclass = declaration.superclass;
    MethodDeclaration? superconstructor;
    if (superclass is ClassDeclaration) {
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
        code = Fragment(
            '$code\n$requiredKeyword${param.type.toCode()} ${param.name},');
      }
      for (var param in superconstructor.namedParameters.values) {
        var requiredKeyword = param.required ? '' : 'required ';
        code = Fragment(
            '$code\n$requiredKeyword${param.type.toCode()} ${param.name},');
      }
    }
    code = Fragment('$code\n})');
    if (superconstructor != null) {
      code = Fragment('$code : super(');
      for (var param in superconstructor.positionalParameters) {
        code = Fragment('$code\n${param.name},');
      }
      if (superconstructor.namedParameters.isNotEmpty) {
        code = Fragment('$code {');
        for (var param in superconstructor.namedParameters.values) {
          code = Fragment('$code\n${param.name}: ${param.name},');
        }
        code = Fragment('$code\n}');
      }
      code = Fragment('$code)');
    }
    builder.addToClass(Declaration('$code;'));
  }
}

const copyWith = CopyWith();

// TODO: How to deal with overriding nullable fields to `null`?
class CopyWith implements ClassDeclarationMacro {
  const CopyWith();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    if (declaration.methods.any((c) => c.name == 'copyWith')) {
      throw ArgumentError(
          'Cannot generate a copyWith method because one already exists');
    }
    var namedParams = <Parameter>[
      for (var field in declaration.allFields)
        Parameter('${field.type.toCode()}${field.type.isNullable ? '' : '?'} '
            '${field.name}'),
    ];
    var args = <NamedArgument>[
      for (var field in declaration.allFields)
        NamedArgument('${field.name}: ${field.name}?? this.${field.name}'),
    ];
    builder.addToClass(Declaration.fromParts([
      declaration.reference,
      Fragment(' copyWith({'),
      Fragment.fromParts(namedParams, ', '),
      Fragment('})'),
      // TODO: We assume this constructor exists, but should check
      Fragment('=> ${declaration.reference}('),
      Fragment.fromParts(args, ', '),
      Fragment(');'),
    ]));
  }
}

const hashCode = HashCode();

class HashCode implements ClassDeclarationMacro {
  const HashCode();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    Code code = Fragment('''
@override
int get hashCode =>''');
    var isFirst = true;
    for (var field in declaration.allFields) {
      code = Fragment('$code ${isFirst ? '' : '^ '}${field.name}.hashCode');
      isFirst = false;
    }
    builder.addToClass(Declaration('$code;'));
  }
}

const equality = Equality();

class Equality implements ClassDeclarationMacro {
  const Equality();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    Code code = Fragment('''
@override
bool operator==(Object other) => other is ${declaration.reference}''');
    for (var field in declaration.allFields) {
      code = Fragment('$code && this.${field.name} == other.${field.name}');
    }
    builder.addToClass(Declaration('$code;'));
  }
}

const toString = ToString();

class ToString implements ClassDeclarationMacro {
  const ToString();

  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    Code code = Fragment('''
@override
String toString() => '\${${declaration.name}} {''');
    var isFirst = true;
    for (var field in declaration.allFields) {
      code = Fragment(
          '$code${isFirst ? '' : ', '}${field.name}: \${${field.name}}');
      isFirst = false;
    }
    builder.addToClass(Declaration('$code}\';'));
  }
}

extension _AllFields on ClassDeclaration {
  // Returns all fields from all super classes.
  Iterable<FieldDeclaration> get allFields sync* {
    yield* fields;
    var next = superclass;
    while (next is ClassDeclaration && next.name != 'Object') {
      yield* next.fields;
      next = next.superclass;
    }
  }
}

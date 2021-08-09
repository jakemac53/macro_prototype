import 'package:collection/collection.dart';
import 'package:macro_builder/definition.dart';

const freezed = _Freezed();

class Default {
  const Default();
}

class _SharedParameter {
  _SharedParameter(this.name, this.type);

  final String name;
  final String type;
}

extension on MethodDeclaration {
  Iterable<ParameterDeclaration> get allParameters sync* {
    yield* positionalParameters;
    yield* namedParameters.values;
  }
}

class _Freezed implements ClassDeclarationMacro {
  const _Freezed();

  Iterable<Declaration> _generateSharedDeclarations(
    ClassDeclaration declaration,
  ) sync* {
    yield Declaration('${declaration.name}._();');

    final sharedParameters = _getSharedParameters(declaration).toList();

    for (final param in sharedParameters) {
      yield Declaration('${param.type} get ${param.name};');
    }

    final copyWithPrototype = _functionPrototypeDefinition([
      for (final param in sharedParameters)
        _Parameter(
          name: param.name,
          type: param.type,
          isRequired: false,
          isNamed: true,
          defaultValue: null,
        ),
    ]);

    yield Declaration('''
${declaration.name} copyWith($copyWithPrototype);
''');

    if (declaration.constructors.length > 1) {
      final fromJsonCases = [
        for (final constructor in declaration.constructors)
          '''
case "${constructor.name}":
  return ${redirectedNameForConstructor(constructor)}.fromJson(json);
'''
      ];

      yield Declaration('''
factory ${declaration.name}.fromJson(Map<String, Object?> json) {
  switch (json['type'] as String?) {
    ${fromJsonCases.join()}
    default: throw FallThroughError();
  }
}
''');

      yield Declaration('''
R when<R>({
  ${declaration.constructors.map(constructorAsWhenParameter).join()}
});
''');
    } else {
      final constructor = declaration.constructors.single;
      final redirectedName = redirectedNameForConstructor(constructor);

      yield Declaration('''
factory ${declaration.name}.fromJson(Map<String, Object?> json) = ${redirectedName}.fromJson;
''');
    }
  }

  Iterable<_SharedParameter> _getSharedParameters(
    ClassDeclaration declaration,
  ) sync* {
    for (final param in declaration.constructors.first.allParameters) {
      final isParameterPresentInAllConstructors =
          declaration.constructors.every((constructor) {
        return constructor.allParameters.any((e) =>
            e.name == param.name &&
            e.type.reference.code == param.type.reference.code);
      });

      if (isParameterPresentInAllConstructors) {
        yield _SharedParameter(param.name, param.type.reference.code);
      }
    }
  }

  @override
  void visitClassDeclaration(
    ClassDeclaration declaration,
    ClassDeclarationBuilder builder,
  ) {
    builder.addToLibrary(Declaration('class Foo {}'));

    // Assuming that the other constructors present are factory constructors
    // as we currently don't have the info
    // TODO why is declaration.constructors typed as List<MethodDeclaration> instead of List<ConstructorDeclaration>?

    if (declaration.constructors.isEmpty) {
      throw ArgumentError(
        'The class must contains at least one redirecting factory constructor',
      );
    }

    _generateSharedDeclarations(declaration).forEach(builder.addToClass);

    for (final constructor in declaration.constructors) {
      builder.addToLibrary(
        Declaration(
          _UnionCaseTemplate(
            constructor: constructor,
            declaration: declaration,
          ).toString(),
        ),
      );
      builder.addToLibrary(
        Declaration(
          _UnionCaseImplTemplate(
            constructor: constructor,
            declaration: declaration,
          ).toString(),
        ),
      );
    }
  }
}

class _UnionCaseTemplate {
  _UnionCaseTemplate({
    required this.constructor,
    required this.declaration,
  });

  final MethodDeclaration constructor;
  final ClassDeclaration declaration;

  @override
  String toString() {
    // TODO support generic classes
    // TODO generate properties common to all union-cases
    // TODO generate switch-case helper methods
    // TODO parse redirecting factory constructors to use the name of the
    // target class as name
    final redirectedName = redirectedNameForConstructor(constructor);
    final redirectedImpl = '_\$$redirectedName';

    final redirectedInterfaceConstructorPrototype =
        _functionPrototypeDefinition([
      for (final parameter in constructor.positionalParameters)
        _Parameter(
          name: parameter.name,
          type: parameter.type.reference.code,
          isRequired: parameter.required,
          isNamed: false,
          defaultValue: null,
        ),
      for (final parameter in constructor.namedParameters.entries)
        _Parameter(
          name: parameter.key,
          type: parameter.value.type.reference.code,
          isRequired: parameter.value.required,
          isNamed: true,
          defaultValue: null,
        ),
    ]);

    final copyWithPrototype = _functionPrototypeDefinition([
      for (final parameter in constructor.allParameters)
        _Parameter(
          name: parameter.name,
          type: parameter.type.reference.code,
          isNamed: true,
          isRequired: false,
          defaultValue: null,
        ),
    ]);

    // TODO support deep de/serialization
    final fromJsonCall = _functionCallDefinition(
      positionalParameters: [
        for (final param in constructor.positionalParameters)
          'json["${param.name}"] as ${param.type.reference.code}',
      ],
      namedParameters: [
        for (final param in constructor.namedParameters.entries)
          '${param.key}: json["${param.key}"] as ${param.value.type.reference.code}',
      ],
    );

    final properties = [
      for (final parameter in constructor.allParameters)
        '${parameter.type.reference.code} get ${parameter.name};'
    ];

    // TODO support const constructors once we have a "constructor.isConst".
    return '''
abstract class $redirectedName extends ${declaration.name} {
  ${redirectedName}._(): super._();

  factory ${redirectedName}($redirectedInterfaceConstructorPrototype) = $redirectedImpl;

  factory ${redirectedName}.fromJson(Map<String, Object?> json) {
    return ${redirectedName}($fromJsonCall);
  }

  ${properties.join()}

  @override
  Map<String, Object?> toJson() {
    return {
      ${constructor.allParameters.map((e) => '"${e.name}": ${e.name}').join(',')}
    };
  }

  @override
  $redirectedName copyWith($copyWithPrototype);
}
''';
  }
}

class _UnionCaseImplTemplate {
  _UnionCaseImplTemplate({
    required this.constructor,
    required this.declaration,
  });

  final MethodDeclaration constructor;
  final ClassDeclaration declaration;

  @override
  String toString() {
    // TODO support generic classes
    // TODO extract comments from constructor parameters to properties
    // TODO parse redirecting factory constructors to use the name of the
    // target class as name
    final redirectedName = redirectedNameForConstructor(constructor);
    final redirectedImpl = '_\$$redirectedName';

    final redirectedInterfaceConstructorPrototype =
        _functionPrototypeDefinition([
      for (final parameter in constructor.positionalParameters)
        // TODO support default values
        _Parameter(
          name: 'this.${parameter.name}',
          type: '',
          isRequired: parameter.required,
          isNamed: false,
          defaultValue: null,
        ),
      for (final parameter in constructor.namedParameters.entries)
        _Parameter(
          name: 'this.${parameter.key}',
          type: '',
          isRequired: parameter.value.required,
          isNamed: true,
          defaultValue: null,
        ),
    ]);

    final copyWithPrototype = _functionPrototypeDefinition([
      for (final parameter in constructor.allParameters)
        _Parameter(
          name: parameter.name,
          type: 'Object?',
          isNamed: true,
          isRequired: false,
          defaultValue: 'const Default()',
        ),
    ]);

    final copyCall = _functionCallDefinition(
      positionalParameters: [
        for (final parameter in constructor.positionalParameters)
          '${parameter.name} == const Default() ? '
              'this.${parameter.name} '
              ': ${parameter.name} as ${parameter.type.reference.code}'
      ],
      namedParameters: [
        for (final parameter in constructor.namedParameters.entries)
          '${parameter.key}: ${parameter.key} == const Default() ? '
              'this.${parameter.key} '
              ': ${parameter.key} as ${parameter.value.type.reference.code}'
      ],
    );

    final properties = [
      for (final parameter in constructor.allParameters)
        'final ${parameter.type.reference.code} ${parameter.name};'
    ];

    var when = '';
    if (declaration.constructors.length > 1) {
      when = '''
@override
R when<R>({
  ${declaration.constructors.map(constructorAsWhenParameter).join()}
}) {
  return ${constructor.name}(
    ${constructor.allParameters.map((p) => p.name).join(',')}
  );
}
''';
    }

    return '''
class $redirectedImpl extends ${redirectedName} {
  ${redirectedImpl}($redirectedInterfaceConstructorPrototype)
    : super._();

  ${properties.join('\n')}

  $when

  @override
  $redirectedImpl copyWith($copyWithPrototype) {
    return ${redirectedImpl}($copyCall);
  }

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
      other is $redirectedImpl
      ${constructor.allParameters.map((e) => '&& other.${e.name} == ${e.name}').join()};
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    ${constructor.allParameters.map((e) => e.name).join(',')}
  ]);
 
  @override
  String toString() {
    return '${redirectedName}(${constructor.allParameters.map((e) => '${e.name}: \$${e.name}').join(', ')})';
  }
}
''';
  }
}

String redirectedNameForConstructor(MethodDeclaration constructor) {
  return '${constructor.definingClass.name}${constructor.name.capitalize}';
}

String constructorAsWhenParameter(MethodDeclaration constructor) {
  final prototype = _functionPrototypeDefinition([
    for (final param in constructor.allParameters)
      _Parameter(
        name: param.name,
        type: param.type.reference.code,
        isNamed: false,
        isRequired: true,
        defaultValue: null,
      )
  ]);

  return 'required R Function($prototype) ${constructor.name},\n';
}

class _Parameter {
  _Parameter({
    required this.name,
    required this.type,
    required this.isRequired,
    required this.isNamed,
    required this.defaultValue,
  });

  final String name;
  final String type;
  final bool isNamed;
  final bool isRequired;
  final Object? defaultValue;
}

extension on String {
  String get capitalize {
    return replaceFirstMapped(
      RegExp(r'[a-zA-Z]'),
      (match) => match.group(0)!.toUpperCase(),
    );
  }
}

String _functionPrototypeDefinition(
  List<_Parameter> parameters,
) {
  // TODO support default values
  final buffer = StringBuffer('');

  final requiredPositional =
      parameters.where((e) => !e.isNamed && e.isRequired).toList();
  final optionalPositional =
      parameters.where((e) => !e.isNamed && !e.isRequired).toList();
  final namedParameters = parameters.where((e) => e.isNamed).toList();

  String buildParameter(_Parameter parameter) {
    final trailing =
        parameter.defaultValue == null ? '' : '= ${parameter.defaultValue}';
    return '${parameter.type} ${parameter.name} $trailing';
  }

  buffer.writeAll(
    requiredPositional.map(buildParameter),
    ',',
  );
  if (requiredPositional.isNotEmpty &&
      (optionalPositional.isNotEmpty || namedParameters.isNotEmpty)) {
    buffer.write(',');
  }

  if (optionalPositional.isNotEmpty) {
    buffer
      ..write('[')
      ..writeAll(
        optionalPositional.map(buildParameter),
        ',',
      )
      ..write(']');

    if (namedParameters.isNotEmpty) buffer.write(',');
  }

  if (namedParameters.isNotEmpty) {
    buffer
      ..write('{')
      ..writeAll(
        namedParameters.map((e) {
          final leading = e.isRequired ? 'required ' : '';
          return '$leading${buildParameter(e)}';
        }),
        ',',
      )
      ..write('}');
  }

  return buffer.toString();
}

String _functionCallDefinition({
  List<String> positionalParameters = const [],
  List<String> namedParameters = const [],
}) {
  final buffer = StringBuffer('');

  buffer.writeAll(positionalParameters, ',');
  if (positionalParameters.isNotEmpty && namedParameters.isNotEmpty) {
    buffer.write(',');
  }

  buffer.writeAll(namedParameters, ',');

  return buffer.toString();
}

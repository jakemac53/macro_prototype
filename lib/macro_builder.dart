import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'src/analyzer.dart';
import 'src/json.dart';
import 'code.dart';
import 'macro.dart';

Builder createBuilder(_) => MacroBuilder([JsonMacro()]);

class MacroBuilder extends Builder {
  final Map<TypeChecker, Macro> macros;

  MacroBuilder(Iterable<Macro> macros)
      : macros = {
          for (var macro in macros)
            TypeChecker.fromRuntime(macro.runtimeType): macro,
        };

  @override
  Future<void> build(BuildStep buildStep) async {
    var library = await buildStep.inputLibrary;
    var buffer = StringBuffer();
    for (var topLevel in library.topLevelElements) {
      _applyMacros(topLevel, buffer);
    }
    if (buffer.isNotEmpty) {
      var outputId = buildStep.inputId.addExtension('.patch');
      var formatted = DartFormatter().format('''
import 'package:macro_builder/patch.dart';
$buffer''', uri: outputId.uri);
      await buildStep.writeAsString(outputId, formatted);
    }
  }

  void _applyMacros(Element element, StringBuffer buffer) {
    if (element is ClassElement) {
      var classBuffer = StringBuffer();
      for (var field in element.fields) {
        _applyMacros(field, classBuffer);
      }
      for (var method in element.methods) {
        _applyMacros(method, classBuffer);
      }
      for (var checker in macros.keys) {
        _maybeApplyMacro(checker, macros[checker]!, element, classBuffer);
      }
      if (classBuffer.isNotEmpty) {
        buffer.writeln('''
@patch
class ${element.name} {
$classBuffer
}''');
      }
    } else {
      for (var checker in macros.keys) {
        _maybeApplyMacro(checker, macros[checker]!, element, buffer);
      }
    }
  }

  void _maybeApplyMacro(
      TypeChecker checker, Macro macro, Element element, StringBuffer buffer) {
    if (!checker.hasAnnotationOf(element)) return;
    if (macro is ClassDefinitionMacro) {
      if (element is! ClassElement) {
        throw ArgumentError(
            'Macro $macro can only be used on classes, but was found on $element');
      }
      macro.define(_ImplementableTargetClassDefinition(element, buffer));
    } else if (macro is FieldDefinitionMacro) {
      if (element is! FieldElement) {
        throw ArgumentError(
            'Macro $macro can only be used on fields, but was found on $element');
      }
      macro.define(_ImplementableTargetFieldDefinition(element, buffer));
    } else if (macro is MethodDefinitionMacro) {
      if (element is! MethodElement) {
        throw ArgumentError(
            'Macro $macro can only be used on methods, but was found on $element');
      }
      macro.define(_ImplementableTargetMethodDefinition(element, buffer));
    } else {
      throw UnsupportedError(
          'This prototype only supports phase 3 (definition) macros');
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.dart': ['.dart.patch'],
      };
}

class _ImplementableTargetClassDefinition
    extends AnalyzerTargetClassDefinition {
  final StringBuffer _buffer;

  _ImplementableTargetClassDefinition(ClassElement element, this._buffer)
      : super(element);

  @override
  Iterable<TargetFieldDefinition> get fields sync* {
    var e = element as ClassElement;
    for (var field in e.fields) {
      yield _ImplementableTargetFieldDefinition(field, _buffer);
    }
  }

  @override
  Iterable<TargetMethodDefinition> get methods sync* {
    var e = element as ClassElement;
    for (var method in e.methods) {
      yield _ImplementableTargetMethodDefinition(method, _buffer);
    }
  }
}

class _ImplementableTargetFieldDefinition
    extends AnalyzerTargetFieldDefinition {
  final StringBuffer _buffer;

  _ImplementableTargetFieldDefinition(FieldElement element, this._buffer)
      : super(element);

  @override
  void withInitializer(Code body) => throw UnimplementedError();

  @override
  void withGetterSetterPair(Code getter, Code setter, {Code? privateField}) =>
      throw UnimplementedError();
}

class _ImplementableTargetMethodDefinition
    extends AnalyzerTargetMethodDefinition {
  final StringBuffer _buffer;

  _ImplementableTargetMethodDefinition(MethodElement element, this._buffer)
      : super(element);

  @override
  void implement(Code code) {
    String writeType(TypeDeclaration d) {
      var type = StringBuffer(d.name);
      if (d.typeArguments.isNotEmpty) {
        type.write('<');
        var types = [];
        for (var typeArg in d.typeArguments) {
          types.add(writeType(typeArg));
        }
        type.write(types.join(', '));
        type.write('>');
      }
      if (d.isNullable) type.write('?');
      return type.toString();
    }

    _buffer.writeln('''
@patch
${writeType(returnType)} ${name}(
''');
    for (var positional in positionalParameters) {
      _buffer.writeln('${writeType(positional.type)} ${positional.name},');
    }
    if (namedParameters.isNotEmpty) {
      _buffer.write(' {');
      for (var named in namedParameters.values) {
        _buffer.writeln(
            '${named.required ? 'required ' : ''}${writeType(named.type)} ${named.name},');
      }
      _buffer.writeln('}');
    }
    _buffer.write(')');
    _buffer.write('$code');
  }
}

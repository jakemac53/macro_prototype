import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'src/analyzer.dart';
import 'src/json.dart';
import 'src/observable.dart';
import 'code.dart';
import 'macro.dart';

Builder typesBuilder(_) => TypesMacroBuilder([toJson, observable]);
Builder declarationsBuilder(_) =>
    DeclarationsMacroBuilder([toJson, observable]);
Builder defintionsBuilder(_) => DefinitionsMacroBuilder([toJson, observable]);

abstract class MacroBuilder extends Builder {
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
      _applyMacros(topLevel, buffer, buffer);
    }
    if (buffer.isNotEmpty) {
      var outputId = buildStep.inputId.addExtension('.patch');
      var formatted = DartFormatter().format('''
import 'package:macro_builder/patch.dart';
$buffer''', uri: outputId.uri);
      await buildStep.writeAsString(outputId, formatted);
    }
  }

  void _applyMacros(
      Element element, StringBuffer buffer, StringBuffer libraryBuffer) {
    if (element is ClassElement) {
      var classBuffer = StringBuffer();
      for (var field in element.fields) {
        _applyMacros(field, classBuffer, libraryBuffer);
      }
      for (var method in element.methods) {
        _applyMacros(method, classBuffer, libraryBuffer);
      }
      for (var checker in macros.keys) {
        maybeApplyMacro(
            checker, macros[checker]!, element, classBuffer, libraryBuffer);
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
        maybeApplyMacro(
            checker, macros[checker]!, element, buffer, libraryBuffer);
      }
    }
  }

  void maybeApplyMacro(TypeChecker checker, Macro macro, Element element,
      StringBuffer buffer, StringBuffer libraryBuffer);
}

class TypesMacroBuilder extends MacroBuilder {
  TypesMacroBuilder(Iterable<Macro> macros) : super(macros);

  @override
  void maybeApplyMacro(TypeChecker checker, Macro macro, Element element,
      StringBuffer buffer, StringBuffer libraryBuffer) {
    if (!checker.hasAnnotationOf(element)) return;
    if (macro is ClassTypeMacro) {
      if (element is! ClassElement) {
        throw ArgumentError(
            'Macro $macro can only be used on classes, but was found on $element');
      }
      macro.type(_ImplementableTargetClassType(element, libraryBuffer));
    }

    throw UnsupportedError(
        'This prototype doesn\'t support phase 1 (type) macros');
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        ".gen.dart": [".types.dart."]
      };
}

class DeclarationsMacroBuilder extends MacroBuilder {
  DeclarationsMacroBuilder(Iterable<Macro> macros) : super(macros);

  @override
  void maybeApplyMacro(TypeChecker checker, Macro macro, Element element,
      StringBuffer buffer, StringBuffer libraryBuffer) {
    if (!checker.hasAnnotationOf(element)) return;
    if (macro is ClassDeclarationMacro) {
      if (element is! ClassElement) {
        throw ArgumentError(
            'Macro $macro can only be used on classes, but was found on $element');
      }
      macro.declare(_ImplementableTargetClassDeclaration(element,
          classBuffer: buffer, libraryBuffer: libraryBuffer));
    }
    if (macro is FieldDeclarationMacro) {
      if (element is! FieldElement) {
        throw ArgumentError(
            'Macro $macro can only be used on fields, but was found on $element');
      }
      macro.declare(_ImplementableTargetFieldDeclaration(element, buffer));
    } else if (macro is FieldDefinitionMacro) {
      if (element is! FieldElement) {
        throw ArgumentError(
            'Macro $macro can only be used on fields, but was found on $element');
      }
      macro.define(_ImplementableTargetFieldDefinition(element, buffer));
    } else if (macro is MethodDeclarationMacro) {
      if (element is! MethodElement) {
        throw ArgumentError(
            'Macro $macro can only be used on methods, but was found on $element');
      }
      macro.declare(_ImplementableTargetMethodDeclaration(element, buffer));
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        ".types.dart.": [".declaration.dart."]
      };
}

class DefinitionsMacroBuilder extends MacroBuilder {
  DefinitionsMacroBuilder(Iterable<Macro> macros) : super(macros);

  @override
  void maybeApplyMacro(TypeChecker checker, Macro macro, Element element,
      StringBuffer buffer, StringBuffer libraryBuffer) {
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
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        ".declaration.dart.": [".dart."]
      };
}

class _ImplementableTargetClassType extends AnalyzerTypeReference
    implements TargetClassType {
  final StringBuffer _libraryBuffer;

  ClassElement get element => super.element as ClassElement;

  _ImplementableTargetClassType(ClassElement element, this._libraryBuffer)
      : super(element);

  Iterable<TypeReference> get superinterfaces sync* {
    for (var interface in element.allSupertypes) {
      yield AnalyzerTypeReference(interface.element,
          originalReference: interface);
    }
  }

  @override
  void addTypeToLibary(Code declaration) => _libraryBuffer.writeln(declaration);
}

class _ImplementableTargetClassDeclaration extends AnalyzerTypeDeclaration
    implements TargetClassDeclaration {
  final StringBuffer _classBuffer;
  final StringBuffer _libraryBuffer;

  _ImplementableTargetClassDeclaration(ClassElement element,
      {required StringBuffer classBuffer, required StringBuffer libraryBuffer})
      : _classBuffer = classBuffer,
        _libraryBuffer = libraryBuffer,
        super(element);

  @override
  Iterable<TargetFieldDeclaration> get fields sync* {
    var e = element as ClassElement;
    for (var field in e.fields) {
      yield _ImplementableTargetFieldDeclaration(field, _classBuffer);
    }
  }

  @override
  Iterable<TargetMethodDeclaration> get methods sync* {
    var e = element as ClassElement;
    for (var method in e.methods) {
      yield _ImplementableTargetMethodDeclaration(method, _classBuffer);
    }
  }

  @override
  void addToClass(Code declaration) => _classBuffer.writeln(declaration);

  @override
  void addToLibrary(Code declaration) => _libraryBuffer.writeln(declaration);
}

class _ImplementableTargetClassDefinition extends AnalyzerTypeDefinition
    implements TargetClassDefinition {
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

class _ImplementableTargetFieldDeclaration extends AnalyzerFieldDeclaration
    implements TargetFieldDeclaration {
  final StringBuffer _classBuffer;
  _ImplementableTargetFieldDeclaration(FieldElement element, this._classBuffer)
      : super(element);

  @override
  void addToClass(Code declaration) => _classBuffer.writeln(declaration);
}

class _ImplementableTargetFieldDefinition extends AnalyzerFieldDefinition
    implements TargetFieldDefinition {
  final StringBuffer _buffer;

  _ImplementableTargetFieldDefinition(FieldElement element, this._buffer)
      : super(element);

  @override
  void withInitializer(Code body, {List<Code>? supportingDeclarations}) {
    _buffer.writeln('''
@patch
${type.toCode()} ${name} = $body;''');
    supportingDeclarations?.forEach(_buffer.writeln);
  }

  @override
  void withGetterSetterPair(Code getter, Code setter,
      {List<Code>? supportingDeclarations}) {
    _buffer.writeln('''
@patch
$getter
@patch
$setter''');
    supportingDeclarations?.forEach(_buffer.writeln);
  }
}

class _ImplementableTargetMethodDeclaration extends AnalyzerMethodDeclaration
    implements TargetMethodDeclaration {
  final StringBuffer _buffer;

  _ImplementableTargetMethodDeclaration(MethodElement element, this._buffer)
      : super(element);

  @override
  void addToClass(Code declaration) => _buffer.writeln(declaration);
}

class _ImplementableTargetMethodDefinition extends AnalyzerMethodDefinition
    implements TargetMethodDefinition {
  final StringBuffer _buffer;

  _ImplementableTargetMethodDefinition(MethodElement element, this._buffer)
      : super(element);

  @override
  void implement(Code code, {List<Code>? supportingDeclarations}) {
    _buffer.writeln('''
@patch
${returnType.toCode()} ${name}(
''');
    for (var positional in positionalParameters) {
      _buffer.writeln('${positional.type.toCode()} ${positional.name},');
    }
    if (namedParameters.isNotEmpty) {
      _buffer.write(' {');
      for (var named in namedParameters.values) {
        _buffer.writeln(
            '${named.required ? 'required ' : ''}${named.type.toCode()} ${named.name},');
      }
      _buffer.writeln('}');
    }
    _buffer.write(')');
    _buffer.write('$code');

    supportingDeclarations?.forEach(_buffer.writeln);
  }
}

extension ToCode on TypeDeclaration {
  // Recreates a string for the type declaration `d`, with type arguments if
  // present as well as retaining `?` markers.
  String toCode() {
    var type = StringBuffer(name);
    if (typeArguments.isNotEmpty) {
      type.write('<');
      var types = [];
      for (var typeArg in typeArguments) {
        types.add(typeArg.toCode());
      }
      type.write(types.join(', '));
      type.write('>');
    }
    if (isNullable) type.write('?');
    return type.toString();
  }
}

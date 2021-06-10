import 'dart:async';

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'src/analyzer.dart';
import 'src/declarations.dart';
import 'src/definitions.dart';
import 'src/code.dart';
import 'src/macro.dart';
import 'src/types.dart';

export 'src/code.dart';
export 'src/declarations.dart';
export 'src/definitions.dart';
export 'src/macro.dart';
export 'src/types.dart';

abstract class _MacroBuilder extends Builder {
  final Map<TypeChecker, Macro> macros;
  final String _inputExtension;
  final String _outputExtension;

  Map<String, List<String>> get buildExtensions => {
        _inputExtension: [_outputExtension]
      };

  _MacroBuilder(
      Iterable<Macro> macros, this._inputExtension, this._outputExtension)
      : macros = {
          for (var macro in macros)
            TypeChecker.fromRuntime(macro.runtimeType): macro,
        };

  @override
  Future<void> build(BuildStep buildStep) async {
    var resolver = await buildStep.resolver;
    var library = await buildStep.inputLibrary;
    var buffer = StringBuffer();
    var ast = await resolver.compilationUnitFor(buildStep.inputId);
    for (var directive in ast.directives) {
      // MEGA HACK: Replace earlier phase imports with next phase ones.
      var directiveSrc =
          directive.toSource().replaceAll(_inputExtension, _outputExtension);
      buffer.writeln(directiveSrc);
    }

    for (var topLevel in library.topLevelElements) {
      await _applyMacros(topLevel, buffer, buffer, resolver,
          await buildStep.readAsString(buildStep.inputId));
    }
    var inputPath = buildStep.inputId.path;
    var outputId = AssetId(
        buildStep.inputId.package,
        inputPath.replaceRange(inputPath.length - _inputExtension.length,
            inputPath.length, _outputExtension));
    var formatted =
        DartFormatter().format(buffer.toString(), uri: outputId.uri);
    await buildStep.writeAsString(outputId, formatted);
  }

  Future<void> _applyMacros(
    Element element,
    StringBuffer buffer,
    StringBuffer libraryBuffer,
    Resolver resolver,
    String originalSource, {
    // We don't want to copy the impls of anything in this list over, they were
    // implemented by a class macro.
    List<String>? implementedDecls,
  }) async {
    if (element.isSynthetic) return;
    if (element is ClassElement) {
      var classBuffer = StringBuffer();
      var clazz = (await resolver.astNodeFor(element, resolve: true))
          as ast.ClassDeclaration;
      var start = clazz.offset;
      var end = clazz.leftBracket.charOffset;
      classBuffer.writeln(originalSource.substring(start, end + 1));

      implementedDecls = [];
      for (var checker in macros.keys) {
        implementedDecls.addAll(await maybeApplyMacro(checker, macros[checker]!,
                element, resolver, classBuffer, libraryBuffer) ??
            const []);
      }
      for (var field in element.fields) {
        await _applyMacros(
            field, classBuffer, libraryBuffer, resolver, originalSource,
            implementedDecls: implementedDecls);
      }
      for (var method in element.methods) {
        await _applyMacros(
            method, classBuffer, libraryBuffer, resolver, originalSource,
            implementedDecls: implementedDecls);
      }
      for (var constructor in element.constructors) {
        await _applyMacros(
            constructor, classBuffer, libraryBuffer, resolver, originalSource,
            implementedDecls: implementedDecls);
      }
      for (var accessor in element.accessors) {
        await _applyMacros(
            accessor, classBuffer, libraryBuffer, resolver, originalSource,
            implementedDecls: implementedDecls);
      }
      classBuffer.writeln('}');
      buffer.writeln(classBuffer);
    } else {
      var memberBuffer = StringBuffer();
      for (var checker in macros.keys) {
        await maybeApplyMacro(checker, macros[checker]!, element, resolver,
            memberBuffer, libraryBuffer);
      }

      if (implementedDecls?.contains(element.name!) != true) {
        var node = (await resolver.astNodeFor(element, resolve: true))!;
        if (element is FieldElement) {
          node = node.parent!.parent!;
        }
        buffer.writeln(node.toSource());
      }
      if (memberBuffer.isNotEmpty) {
        buffer.writeln(memberBuffer);
      }
    }
  }

  // When applied to classes, returns the list names of the modified
  // declarations during execution of this macro
  Future<List<String>?> maybeApplyMacro(
      TypeChecker checker,
      Macro macro,
      Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer);
}

class TypesMacroBuilder extends _MacroBuilder {
  TypesMacroBuilder(Iterable<TypeMacro> macros)
      : super(macros, '.gen.dart', '.types.dart');

  @override
  Future<List<String>?> maybeApplyMacro(
      TypeChecker checker,
      Macro macro,
      Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer) async {
    if (!checker.hasAnnotationOf(element)) return null;
    if (macro is ClassTypeMacro) {
      if (element is! ClassElement) {
        throw ArgumentError(
            'Macro $macro can only be used on classes, but was found on $element');
      }
      macro.type(_ImplementableTargetClassType(element, libraryBuffer));
    }
  }
}

class DeclarationsMacroBuilder extends _MacroBuilder {
  DeclarationsMacroBuilder(Iterable<DeclarationMacro> macros)
      : super(macros, '.types.dart', '.declarations.dart');

  @override
  Future<List<String>?> maybeApplyMacro(
      TypeChecker checker,
      Macro macro,
      Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer) async {
    if (!checker.hasAnnotationOf(element)) return null;
    if (macro is ClassDeclarationMacro) {
      if (element is! ClassElement) {
        throw ArgumentError(
            'Macro $macro can only be used on classes, but was found on $element');
      }
      macro.declare(_ImplementableTargetClassDeclaration(element,
          classBuffer: buffer, libraryBuffer: libraryBuffer));
      // TODO: return list of names of declarations modified
    }
    if (macro is FieldDeclarationMacro) {
      if (element is! FieldElement) {
        throw ArgumentError(
            'Macro $macro can only be used on fields, but was found on $element');
      }
      macro.declare(_ImplementableTargetFieldDeclaration(element, buffer));
    } else if (macro is MethodDeclarationMacro) {
      if (element is! MethodElement) {
        throw ArgumentError(
            'Macro $macro can only be used on methods, but was found on $element');
      }
      macro.declare(_ImplementableTargetMethodDeclaration(element, buffer));
    }
  }
}

class DefinitionsMacroBuilder extends _MacroBuilder {
  DefinitionsMacroBuilder(Iterable<DefinitionMacro> macros)
      : super(macros, '.declarations.dart', '.dart');

  @override
  Future<List<String>?> maybeApplyMacro(
      TypeChecker checker,
      Macro macro,
      Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer) async {
    if (!checker.hasAnnotationOf(element)) return null;
    if (macro is ClassDefinitionMacro) {
      if (element is! ClassElement) {
        throw ArgumentError(
            'Macro $macro can only be used on classes, but was found on $element');
      }
      var targetClass = _ImplementableTargetClassDefinition(element, buffer);
      macro.define(targetClass);
      return targetClass._implementedDeclarations;
    } else if (macro is FieldDefinitionMacro) {
      if (element is! FieldElement) {
        throw ArgumentError(
            'Macro $macro can only be used on fields, but was found on $element');
      }
      var fieldBuffer = StringBuffer();
      macro.define(_ImplementableTargetFieldDefinition(element, buffer));
      if (fieldBuffer.isNotEmpty) {
        var node = (await resolver.astNodeFor(element, resolve: true))!
            .parent!
            .parent as ast.FieldDeclaration;
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(fieldBuffer);
      }
    } else if (macro is MethodDefinitionMacro) {
      if (element is! MethodElement) {
        throw ArgumentError(
            'Macro $macro can only be used on methods, but was found on $element');
      }
      var methodBuffer = StringBuffer();
      macro.define(_ImplementableTargetMethodDefinition(element, methodBuffer));
      if (methodBuffer.isNotEmpty) {
        var node = (await resolver.astNodeFor(element, resolve: true))
            as ast.MethodDeclaration;
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(methodBuffer);
      }
    }
  }
}

class _ImplementableTargetClassType extends AnalyzerTypeReference
    implements TargetClassType {
  final StringBuffer _libraryBuffer;

  ClassElement get element => super.element as ClassElement;

  _ImplementableTargetClassType(ClassElement element, this._libraryBuffer)
      : super(element);

  @override
  bool get isAbstract => element.isAbstract;

  @override
  bool get isExternal => throw UnsupportedError(
      'Analyzer doesn\'t have an isExternal getter for classes.');

  @override
  void addTypeToLibary(Code declaration) => _libraryBuffer.writeln(declaration);
}

class _ImplementableTargetClassDeclaration extends AnalyzerTypeDeclaration
    implements TargetClassDeclaration {
  final StringBuffer _classBuffer;
  final StringBuffer _libraryBuffer;

  ClassElement get element => super.element as ClassElement;

  _ImplementableTargetClassDeclaration(ClassElement element,
      {required StringBuffer classBuffer, required StringBuffer libraryBuffer})
      : _classBuffer = classBuffer,
        _libraryBuffer = libraryBuffer,
        super(element);

  @override
  Iterable<TargetMethodDeclaration> get constructors sync* {
    for (var constructor in element.constructors) {
      yield _ImplementableTargetConstructorDeclaration(
          constructor, _classBuffer);
    }
  }

  @override
  Iterable<TargetFieldDeclaration> get fields sync* {
    for (var field in element.fields) {
      yield _ImplementableTargetFieldDeclaration(field, _classBuffer);
    }
  }

  @override
  Iterable<TargetMethodDeclaration> get methods sync* {
    for (var method in element.methods) {
      yield _ImplementableTargetMethodDeclaration(method, _classBuffer);
    }
  }

  @override
  TargetTypeDeclaration? get superclass {
    if (element.isDartCoreObject) return null;
    var superType = element.supertype!;
    return AnalyzerTargetTypeDeclaration(superType.element,
        originalReference: superType);
  }

  @override
  void addToClass(Code declaration) => _classBuffer.writeln(declaration);

  @override
  void addToLibrary(Code declaration) => _libraryBuffer.writeln(declaration);
}

class _ImplementableTargetClassDefinition extends AnalyzerTypeDefinition
    implements TargetClassDefinition {
  final StringBuffer _buffer;

  // Names of declarations implemented during execution of this macro.
  final _implementedDeclarations = <String>[];

  _ImplementableTargetClassDefinition(ClassElement element, this._buffer)
      : super(element);

  @override
  Iterable<TargetMethodDefinition> get constructors sync* {
    var e = element as ClassElement;
    for (var constructor in e.constructors) {
      if (constructor.isSynthetic) continue;
      yield _ImplementableTargetConstructorDefinition(
          constructor, _buffer, this);
    }
  }

  @override
  Iterable<TargetFieldDefinition> get fields sync* {
    var e = element as ClassElement;
    for (var field in e.fields) {
      if (field.isSynthetic) continue;
      yield _ImplementableTargetFieldDefinition(field, _buffer,
          parentClass: this);
    }
  }

  @override
  Iterable<TargetMethodDefinition> get methods sync* {
    var e = element as ClassElement;
    for (var method in e.methods) {
      if (method.isSynthetic) continue;
      yield _ImplementableTargetMethodDefinition(method, _buffer,
          parentClass: this);
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
  final _ImplementableTargetClassDefinition? parentClass;

  _ImplementableTargetFieldDefinition(FieldElement element, this._buffer,
      {this.parentClass})
      : super(element);

  @override
  void withInitializer(Code body, {List<Code>? supportingDeclarations}) {
    parentClass?._implementedDeclarations.add(name);
    _buffer.writeln('''
${type.toCode()} ${name} = $body;''');
    supportingDeclarations?.forEach(_buffer.writeln);
  }

  @override
  void withGetterSetterPair(Code getter, Code setter,
      {List<Code>? supportingDeclarations}) {
    parentClass?._implementedDeclarations.add(name);
    _buffer..writeln(getter)..writeln(setter);
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
  final _ImplementableTargetClassDefinition? parentClass;

  _ImplementableTargetMethodDefinition(MethodElement element, this._buffer,
      {this.parentClass})
      : super(element);

  @override
  void implement(Code code, {List<Code>? supportingDeclarations}) {
    parentClass?._implementedDeclarations.add(name);
    _buffer.writeln('${returnType.toCode()} ${name}(');
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

class _ImplementableTargetConstructorDeclaration
    extends AnalyzerConstructorDeclaration implements TargetMethodDeclaration {
  final StringBuffer _buffer;

  _ImplementableTargetConstructorDeclaration(
      ConstructorElement element, this._buffer)
      : super(element);

  @override
  void addToClass(Code declaration) => _buffer.writeln(declaration);
}

class _ImplementableTargetConstructorDefinition
    extends AnalyzerConstructorDefinition implements TargetMethodDefinition {
  final StringBuffer _buffer;
  final _ImplementableTargetClassDefinition parentClass;

  _ImplementableTargetConstructorDefinition(
      ConstructorElement element, this._buffer, this.parentClass)
      : super(element);

  @override
  void implement(Code code, {List<Code>? supportingDeclarations}) {
    parentClass._implementedDeclarations.add(name);
    _buffer.writeln('${parentClass.name}.${name}(');
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

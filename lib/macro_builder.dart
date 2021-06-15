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

  _MacroBuilder.forSpecialAnnotation(
      Map<Object, Macro> macros, this._inputExtension, this._outputExtension)
      : macros = {
          for (var entry in macros.entries)
            TypeChecker.fromRuntime(entry.key.runtimeType): entry.value,
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
    try {
      var formatted =
          DartFormatter().format(buffer.toString(), uri: outputId.uri);
      await buildStep.writeAsString(outputId, formatted);
    } catch (e, s) {
      log.severe('Failed to format file $buffer', e, s);
    }
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
    implementedDecls ??= [];
    if (element is ClassElement) {
      var classBuffer = StringBuffer();
      var clazz = (await resolver.astNodeFor(element, resolve: true))
          as ast.ClassDeclaration;
      var start = clazz.offset;
      var end = clazz.leftBracket.charOffset;
      classBuffer.writeln(originalSource.substring(start, end + 1));

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
        implementedDecls.addAll(await maybeApplyMacro(checker, macros[checker]!,
                element, resolver, memberBuffer, libraryBuffer) ??
            const []);
      }

      if (implementedDecls.contains(element.name!) != true) {
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

  TypesMacroBuilder.forSpecialAnnotation(Map<Object, Macro> macros)
      : super.forSpecialAnnotation(macros, '.gen.dart', '.types.dart');

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
      macro.visitClassType(
          AnalyzerClassType(element), _MacroTypeBuilder(libraryBuffer));
    }
  }
}

class DeclarationsMacroBuilder extends _MacroBuilder {
  DeclarationsMacroBuilder(Iterable<DeclarationMacro> macros)
      : super(macros, '.types.dart', '.declarations.dart');

  DeclarationsMacroBuilder.forSpecialAnnotation(Map<Object, Macro> macros)
      : super.forSpecialAnnotation(macros, '.types.dart', '.declarations.dart');

  @override
  Future<List<String>?> maybeApplyMacro(
      TypeChecker checker,
      Macro macro,
      Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer) async {
    if (!checker.hasAnnotationOf(element)) return null;
    if (element is ClassElement) {
      if (macro is! ClassDeclarationMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on classes but was found on '
            '$element');
      }
      macro.visitClassDeclaration(
          AnalyzerClassDeclaration(element),
          _MacroClassDeclarationBuilder(
              classBuffer: buffer, libraryBuffer: libraryBuffer));
      // TODO: return list of names of declarations modified
    } else if (element is FieldElement) {
      if (macro is! FieldDeclarationMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on fields but was found on '
            '$element');
      }
      macro.visitFieldDeclaration(
          AnalyzerFieldDeclaration(element),
          _MacroClassDeclarationBuilder(
              classBuffer: buffer, libraryBuffer: libraryBuffer));
    } else if (element is MethodElement || element is ConstructorElement) {
      if (macro is! MethodDeclarationMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on methods or constructors, '
            'but was found on $element');
      }
      macro.visitMethodDeclaration(
          AnalyzerMethodDeclaration(element as ExecutableElement),
          _MacroClassDeclarationBuilder(
              classBuffer: buffer, libraryBuffer: libraryBuffer));
    } else if (element is FunctionElement) {
      if (macro is! FunctionDeclarationMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on top level functions, '
            'but was found on $element');
      }
      macro.visitFunctionDeclaration(AnalyzerMethodDeclaration(element),
          _MacroLibraryDeclarationBuilder(libraryBuffer: libraryBuffer));
    }
  }
}

class DefinitionsMacroBuilder extends _MacroBuilder {
  DefinitionsMacroBuilder(Iterable<DefinitionMacro> macros)
      : super(macros, '.declarations.dart', '.dart');

  DefinitionsMacroBuilder.forSpecialAnnotation(Map<Object, Macro> macros)
      : super.forSpecialAnnotation(macros, '.declarations.dart', '.dart');

  @override
  Future<List<String>?> maybeApplyMacro(
      TypeChecker checker,
      Macro macro,
      Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer) async {
    if (!checker.hasAnnotationOf(element)) return null;
    if (element is FieldElement) {
      if (macro is! FieldDefinitionMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on fields but was found on '
            '$element');
      }
      var fieldBuffer = StringBuffer();
      var definition = AnalyzerFieldDefinition(element,
          parentClass: element.enclosingElement as ClassElement?);
      var parent =
          AnalyzerClassDefinition(element.enclosingElement as ClassElement);
      macro.visitFieldDefinition(
          definition, _MacroFieldDefinitionBuilder(buffer, definition, parent));
      if (fieldBuffer.isNotEmpty) {
        var node = (await resolver.astNodeFor(element, resolve: true))!
            .parent!
            .parent as ast.FieldDeclaration;
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(fieldBuffer);
        return [element.name];
      }
    } else if (element is MethodElement || element is ConstructorElement) {
      if (macro is! MethodDefinitionMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on methods or constructors, '
            'but was found on $element');
      }
      var methodBuffer = StringBuffer();
      FunctionDefinitionBuilder builder;
      MethodDefinition definition;
      var parent =
          AnalyzerClassDefinition(element.enclosingElement as ClassElement);
      if (element is MethodElement) {
        definition = AnalyzerMethodDefinition(element,
            parentClass: element.enclosingElement as ClassElement);
        builder =
            _MacroFunctionDefinitionBuilder(methodBuffer, definition, parent);
      } else if (element is ConstructorElement) {
        definition = AnalyzerMethodDefinition(element,
            parentClass: element.enclosingElement);
        builder = _MacroConstructorDefinitionBuilder(
            methodBuffer, definition, parent);
      } else {
        throw StateError('unreachable');
      }
      macro.visitMethodDefinition(definition, builder);
      if (methodBuffer.isNotEmpty) {
        var node = (await resolver.astNodeFor(element, resolve: true))
            as ast.AnnotatedNode;
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(methodBuffer);
        return [(element as ExecutableElement).name];
      }
    } else if (element is FunctionElement) {
      if (macro is! FunctionDefinitionMacro) {
        throw ArgumentError(
            'Macro $macro does not support running on methods or constructors, '
            'but was found on $element');
      }
      var fnBuffer = StringBuffer();
      var definition = AnalyzerFunctionDefinition(element);
      var parent =
          AnalyzerClassDefinition(element.enclosingElement as ClassElement);
      var builder =
          _MacroFunctionDefinitionBuilder(fnBuffer, definition, parent);
      macro.visitFunctionDefinition(definition, builder);
      if (fnBuffer.isNotEmpty) {
        var node = (await resolver.astNodeFor(element, resolve: true))
            as ast.AnnotatedNode;
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(fnBuffer);
        return [element.name];
      }
    }
  }
}

class _MacroTypeBuilder implements TypeBuilder {
  final StringBuffer _libraryBuffer;

  _MacroTypeBuilder(this._libraryBuffer);

  @override
  void addTypeToLibary(Code declaration) => _libraryBuffer.writeln(declaration);
}

class _MacroLibraryDeclarationBuilder implements DeclarationBuilder {
  final StringBuffer _libraryBuffer;

  _MacroLibraryDeclarationBuilder({required StringBuffer libraryBuffer})
      : _libraryBuffer = libraryBuffer;

  @override
  void addToLibrary(Code declaration) => _libraryBuffer.writeln(declaration);
}

class _MacroClassDeclarationBuilder extends _MacroLibraryDeclarationBuilder
    implements ClassDeclarationBuilder {
  final StringBuffer _classBuffer;

  _MacroClassDeclarationBuilder(
      {required StringBuffer classBuffer, required StringBuffer libraryBuffer})
      : _classBuffer = classBuffer,
        super(libraryBuffer: libraryBuffer);

  @override
  void addToClass(Code declaration) => _classBuffer.writeln(declaration);
}

class _MacroFieldDefinitionBuilder implements FieldDefinitionBuilder {
  final StringBuffer _buffer;
  final FieldDefinition _definition;
  final ClassDefinition definingClass;

  _MacroFieldDefinitionBuilder(
      this._buffer, this._definition, this.definingClass);

  @override
  void withInitializer(Code body, {List<Code>? supportingDeclarations}) {
    _buffer.writeln('''
${_definition.type.toCode()} ${_definition.name} = $body;''');
    supportingDeclarations?.forEach(_buffer.writeln);
  }

  @override
  void withGetterSetterPair(Code getter, Code setter,
      {List<Code>? supportingDeclarations}) {
    if (!_definition.isAbstract && !_definition.isExternal) {
      throw 'Cannot implement non-abstract or external field $_definition';
    }
    _buffer..writeln(getter)..writeln(setter);
    supportingDeclarations?.forEach(_buffer.writeln);
  }
}

class _MacroFunctionDefinitionBuilder implements FunctionDefinitionBuilder {
  final StringBuffer _buffer;
  final FunctionDefinition _definition;
  final ClassDefinition definingClass;

  _MacroFunctionDefinitionBuilder(
      this._buffer, this._definition, this.definingClass);

  @override
  void implement(Code code, {List<Code>? supportingDeclarations}) {
    _buffer.writeln('${_definition.returnType.toCode()} ${_definition.name}(');
    for (var positional in _definition.positionalParameters) {
      _buffer.writeln('${positional.type.toCode()} ${positional.name},');
    }
    if (_definition.namedParameters.isNotEmpty) {
      _buffer.write(' {');
      for (var named in _definition.namedParameters.values) {
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

class _MacroConstructorDefinitionBuilder implements FunctionDefinitionBuilder {
  final StringBuffer _buffer;
  final MethodDefinition _definition;
  final ClassDefinition definingClass;

  _MacroConstructorDefinitionBuilder(
      this._buffer, this._definition, this.definingClass);

  @override
  void implement(Code code, {List<Code>? supportingDeclarations}) {
    _buffer.writeln('${definingClass.name}.${_definition.name}(');
    for (var positional in _definition.positionalParameters) {
      _buffer.writeln('${positional.type.toCode()} ${positional.name},');
    }
    if (_definition.namedParameters.isNotEmpty) {
      _buffer.write(' {');
      for (var named in _definition.namedParameters.values) {
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

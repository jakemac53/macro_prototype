import 'dart:async';
import 'dart:mirrors';

import 'package:analyzer/dart/ast/ast.dart' as analyzer;
import 'package:analyzer/dart/constant/value.dart' as analyzer;
import 'package:analyzer/dart/element/element.dart' as analyzer;
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

import 'definition.dart';
import 'src/analyzer.dart';

abstract class _MacroBuilder extends Builder {
  final Map<TypeChecker, Macro> macros;
  final String _inputExtension;
  final String _outputExtension;

  @override
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
    var resolver = buildStep.resolver;
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
    analyzer.Element element,
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
    if (element is analyzer.ClassElement) {
      var classBuffer = StringBuffer();
      var clazz = (await resolver.astNodeFor(element, resolve: true))
          as analyzer.ClassDeclaration;
      var start = clazz.offset;
      var end = clazz.leftBracket.charOffset;
      classBuffer.writeln(originalSource.substring(start, end + 1));

      for (var checker in macros.keys) {
        implementedDecls.addAll(await maybeApplyMacro(
                checker,
                macros[checker]!,
                element,
                resolver,
                classBuffer,
                libraryBuffer,
                originalSource) ??
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
        implementedDecls.addAll(await maybeApplyMacro(
                checker,
                macros[checker]!,
                element,
                resolver,
                memberBuffer,
                libraryBuffer,
                originalSource) ??
            const []);
      }

      if (implementedDecls.contains(element.name!) != true) {
        var node = (await resolver.astNodeFor(element, resolve: true))!;
        if (element is analyzer.FieldElement) {
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
      analyzer.Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer,
      String originalSource);
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
      analyzer.Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer,
      String originalSource) async {
    if (!checker.hasAnnotationOf(element)) return null;
    _checkValidMacroApplication(element, macro);
    macro = _instantiateFromMeta(macro, checker.firstAnnotationOf(element)!);
    if (macro is ClassTypeMacro && element is analyzer.ClassElement) {
      macro.visitClassType(
          AnalyzerClassType(element), _MacroTypeBuilder(libraryBuffer));
    } else if (element is analyzer.FieldElement && macro is FieldTypeMacro) {
      throw UnimplementedError(
          'FieldTypeMacro is not implemented in this prototype');
    } else if (element is analyzer.MethodElement && macro is MethodTypeMacro) {
      macro.visitMethodType(
          AnalyzerMethodType(element), _MacroTypeBuilder(libraryBuffer));
    } else if (element is analyzer.ConstructorElement &&
        macro is ConstructorTypeMacro) {
      macro.visitConstructorType(
          AnalyzerConstructorType(element), _MacroTypeBuilder(libraryBuffer));
    } else if (element is analyzer.FunctionElement &&
        macro is FunctionTypeMacro) {
      macro.visitFunctionType(
          AnalyzerFunctionType(element), _MacroTypeBuilder(libraryBuffer));
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
      analyzer.Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer,
      String originalSource) async {
    if (!checker.hasAnnotationOf(element)) return null;
    _checkValidMacroApplication(element, macro);
    macro = _instantiateFromMeta(macro, checker.firstAnnotationOf(element)!);
    if (element is analyzer.ClassElement && macro is ClassDeclarationMacro) {
      macro.visitClassDeclaration(
          AnalyzerClassDeclaration(element),
          _MacroClassDeclarationBuilder(
              classBuffer: buffer, libraryBuffer: libraryBuffer));

      // TODO: return list of names of declarations modified
    } else if (element is analyzer.FieldElement &&
        macro is FieldDeclarationMacro) {
      macro.visitFieldDeclaration(
          AnalyzerFieldDeclaration(element),
          _MacroClassDeclarationBuilder(
              classBuffer: buffer, libraryBuffer: libraryBuffer));
    } else if ((element is analyzer.MethodElement ||
            element is analyzer.ConstructorElement) &&
        macro is MethodDeclarationMacro) {
      macro.visitMethodDeclaration(
          AnalyzerMethodDeclaration(element as analyzer.ExecutableElement),
          _MacroClassDeclarationBuilder(
              classBuffer: buffer, libraryBuffer: libraryBuffer));
    } else if (element is analyzer.FunctionElement &&
        macro is FunctionDeclarationMacro) {
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
      analyzer.Element element,
      Resolver resolver,
      StringBuffer buffer,
      StringBuffer libraryBuffer,
      String originalSource) async {
    if (!checker.hasAnnotationOf(element)) return null;
    _checkValidMacroApplication(element, macro);
    macro = _instantiateFromMeta(macro, checker.firstAnnotationOf(element)!);
    if (element is analyzer.FieldElement && macro is FieldDefinitionMacro) {
      var fieldBuffer = StringBuffer();
      var definition = AnalyzerFieldDefinition(element,
          parentClass: element.enclosingElement as analyzer.ClassElement?);
      var parent = AnalyzerClassDefinition(
          element.enclosingElement as analyzer.ClassElement);
      macro.visitFieldDefinition(
          definition, _MacroFieldDefinitionBuilder(buffer, definition, parent));
      if (fieldBuffer.isNotEmpty) {
        var node = (await resolver.astNodeFor(element, resolve: true))!
            .parent!
            .parent as analyzer.FieldDeclaration;
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(fieldBuffer);
        return [element.name];
      }
    } else if (element is analyzer.MethodElement &&
        macro is MethodDefinitionMacro) {
      var methodBuffer = StringBuffer();
      FunctionDefinitionBuilder builder;
      MethodDefinition definition;
      var parent = AnalyzerClassDefinition(
          element.enclosingElement as analyzer.ClassElement);
      var node = (await resolver.astNodeFor(element, resolve: true))
          as analyzer.Declaration;
      definition = AnalyzerMethodDefinition(element,
          parentClass: element.enclosingElement as analyzer.ClassElement);
      builder = _MacroFunctionDefinitionBuilder(
          methodBuffer, definition, parent, node, originalSource);
      macro.visitMethodDefinition(definition, builder);
      if (methodBuffer.isNotEmpty) {
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(methodBuffer);
        return [element.name];
      }
    } else if (element is analyzer.ConstructorElement &&
        macro is ConstructorDefinitionMacro) {
      var methodBuffer = StringBuffer();
      ConstructorDefinitionBuilder builder;
      ConstructorDefinition definition;
      var parent = AnalyzerClassDefinition(element.enclosingElement);
      var node = (await resolver.astNodeFor(element, resolve: true))
          as analyzer.ConstructorDeclaration;
      definition = AnalyzerConstructorDefinition(element,
          parentClass: element.enclosingElement);
      builder = _MacroConstructorDefinitionBuilder(
          methodBuffer, definition, parent, node, originalSource);

      macro.visitConstructorDefinition(definition, builder);
      if (methodBuffer.isNotEmpty) {
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(methodBuffer);
        return [element.name];
      }
    } else if (element is analyzer.FunctionElement &&
        macro is FunctionDefinitionMacro) {
      var fnBuffer = StringBuffer();
      var definition = AnalyzerFunctionDefinition(element);
      var parent = AnalyzerClassDefinition(
          element.enclosingElement as analyzer.ClassElement);
      var node = (await resolver.astNodeFor(element, resolve: true))
          as analyzer.Declaration;
      var builder = _MacroFunctionDefinitionBuilder(
          fnBuffer, definition, parent, node, originalSource);
      macro.visitFunctionDefinition(definition, builder);
      if (fnBuffer.isNotEmpty) {
        for (var meta in node.metadata) {
          buffer.writeln(meta.toSource());
        }
        buffer.writeln(fnBuffer);
        return [element.name];
      }
    }
  }
}

/// Throws if [element] is annotated with a macro that doesn't support that
/// type of declaration.
void _checkValidMacroApplication(analyzer.Element element, Macro macro) {
  if (element is analyzer.ClassElement) {
    if (macro is! ClassTypeMacro && macro is! ClassDeclarationMacro) {
      throw ArgumentError(
          'Macro $macro does not support running on classes but was found on '
          '$element');
    }
    // TODO: return list of names of declarations modified
  } else if (element is analyzer.FieldElement) {
    if (macro is! FieldTypeMacro &&
        macro is! FieldDeclarationMacro &&
        macro is! FieldDefinitionMacro) {
      throw ArgumentError(
          'Macro $macro does not support running on fields but was found on '
          '$element');
    }
  } else if (element is analyzer.MethodElement ||
      element is analyzer.ConstructorElement) {
    if (macro is! MethodTypeMacro &&
        macro is! MethodDeclarationMacro &&
        macro is! MethodDefinitionMacro) {
      throw ArgumentError(
          'Macro $macro does not support running on methods or constructors, '
          'but was found on $element');
    }
  } else if (element is analyzer.FunctionElement) {
    if (macro is! FunctionTypeMacro &&
        macro is! FunctionDeclarationMacro &&
        macro is! FunctionDefinitionMacro) {
      throw ArgumentError(
          'Macro $macro does not support running on top level functions, '
          'but was found on $element');
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

class _MacroConstructorDefinitionBuilder
    implements ConstructorDefinitionBuilder {
  final StringBuffer _buffer;
  final FunctionDefinition _definition;
  final ClassDefinition definingClass;
  final analyzer.ConstructorDeclaration _node;
  final String _originalSource;

  _MacroConstructorDefinitionBuilder(this._buffer, this._definition,
      this.definingClass, this._node, this._originalSource);

  @override
  void implement({FunctionBody? body, List<Code>? initializers}) {
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
    if (initializers != null) {
      _buffer.write(' : ');
      for (var initializer in initializers) {
        _buffer.writeln(
            '${initializer.code}${initializer == initializers.last ? '' : ','}');
      }
    }
    if (body != null) {
      _buffer.write(body.code);
    } else {
      _buffer.write(';');
    }
  }

  @override
  void wrapBody({List<Statement>? before, List<Statement>? after}) {
    before ??= const [];
    after ??= const [];
    var node = _node;
    var body = node.body;
    var formalParams = node.parameters;
    if (body is! analyzer.BlockFunctionBody) {
      throw UnsupportedError(
          'Only block function bodies can be wrapped but got $body.');
    }

    // Write everything up to the first open curly bracket
    _buffer.write(_originalSource.substring(
        node.firstTokenAfterCommentAndMetadata.offset,
        body.block.leftBracket.offset + 1));

    // Write out the local function which is identical to the original
    _buffer.write(
        // Alert! Hack incoming :D
        '\$original' +
            _originalSource.substring(
                formalParams.leftParenthesis.offset, node.end + 1));

    // Write out the before statements
    for (var stmt in before) {
      _buffer.writeln(stmt.code);
    }

    // Invocation of `original`.
    _buffer.writeln('var \$ret = \$original');

    // Normal args
    _buffer.write('(');
    for (var param in formalParams.parameters) {
      var prefix = param.isNamed ? '${param.identifier!.name}: ' : '';
      _buffer.writeln('$prefix${param.identifier!.name}, ');
    }
    _buffer.writeln(');');

    // Write out the after statements
    for (var stmt in after) {
      _buffer.writeln(stmt.code);
    }

    // Return the original value and close the block.
    _buffer.writeln('return \$ret;\n}');
  }
}

class _MacroFunctionDefinitionBuilder implements FunctionDefinitionBuilder {
  final StringBuffer _buffer;
  final FunctionDefinition _definition;
  final ClassDefinition definingClass;
  final analyzer.Declaration _node;
  final String _originalSource;

  _MacroFunctionDefinitionBuilder(this._buffer, this._definition,
      this.definingClass, this._node, this._originalSource);

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

  @override
  void wrapBody(
      {List<Statement>? before,
      List<Statement>? after,
      List<Declaration>? supportingDeclarations}) {
    before ??= const [];
    after ??= const [];
    var node = _node;
    analyzer.FunctionBody body;
    analyzer.TypeParameterList? typeParams;
    analyzer.FormalParameterList? formalParams;
    if (node is analyzer.MethodDeclaration) {
      body = node.body;
      typeParams = node.typeParameters;
      formalParams = node.parameters;
    } else if (node is analyzer.FunctionDeclaration) {
      body = node.functionExpression.body;
      typeParams = node.functionExpression.typeParameters;
      formalParams = node.functionExpression.parameters;
    } else {
      throw UnsupportedError(
          'Can only wrap normal functions and methods but got $_node');
    }
    if (body is! analyzer.BlockFunctionBody) {
      throw UnsupportedError(
          'Only block function bodies can be wrapped but got $body.');
    }

    // Write everything up to the first open curly bracket
    _buffer.write(_originalSource.substring(
        node.firstTokenAfterCommentAndMetadata.offset,
        body.block.leftBracket.offset + 1));

    // Write out the local function which is identical to the original
    _buffer.write(_originalSource
        .substring(node.firstTokenAfterCommentAndMetadata.offset, node.end + 1)
        // Alert! Hack incoming :D
        .replaceFirst(_definition.name, '\$original'));

    // Write out the before statements
    for (var stmt in before) {
      _buffer.writeln(stmt.code);
    }

    // Invocation of `original`.
    _buffer.writeln('var \$ret = \$original');

    // Type args
    if (typeParams != null) {
      _buffer.write('<');
      var isFirst = true;
      for (var typeParam in typeParams.typeParameters) {
        _buffer.write('${isFirst ? '' : ', '}${typeParam.name.name}');
        isFirst = false;
      }
      _buffer.write('>');
    }

    // Normal args
    _buffer.write('(');
    if (formalParams != null) {
      for (var param in formalParams.parameters) {
        var prefix = param.isNamed ? '${param.identifier!.name}: ' : '';
        _buffer.writeln('$prefix${param.identifier!.name}, ');
      }
    }
    _buffer.writeln(');');

    // Write out the after statements
    for (var stmt in after) {
      _buffer.writeln(stmt.code);
    }

    // Return the original value and close the block.
    _buffer.writeln('return \$ret;\n}');
  }
}

Macro _instantiateFromMeta(Macro macro, analyzer.DartObject constant) {
  var clazz = reflectClass(macro.runtimeType);
  var constructor = clazz.declarations.values.firstWhere((d) =>
          d is MethodMirror && (d.isConstructor || d.isFactoryConstructor))
      as MethodMirror;

  var fields = clazz.declarations.values.whereType<VariableMirror>();
  var reader = ConstantReader(constant);
  var positionalArguments = [];
  var namedArguments = <Symbol, Object?>{};
  for (var param in constructor.parameters) {
    var field =
        fields.firstWhere((field) => field.simpleName == param.simpleName);
    var value = reader.read(field.simpleName
        .toString()
        .replaceFirst('Symbol("', '')
        .replaceFirst('")', ''));
    if (!value.isLiteral) {
      throw UnsupportedError(
          'Only literal values are supported for macro constructors');
    }
    if (param.isNamed) {
      namedArguments[param.simpleName] = value.literalValue;
    } else {
      positionalArguments.add(value.literalValue);
    }
  }
  return clazz
      .newInstance(
          constructor.constructorName, positionalArguments, namedArguments)
      .reflectee as Macro;
}

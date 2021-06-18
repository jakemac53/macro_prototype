import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/error/listener.dart';

import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/string_source.dart';

// TODO: something meaningful :P
abstract class Scope {}

/// The representation of a piece of Code.
abstract class Code {
  String get code;

  @override
  String toString() => code;
}

/// A piece of code that can't be parsed into a valid language construct in its
/// current form. No validation or parsing is performed.
class Fragment extends Code {
  @override
  final String code;

  Fragment(this.code);

  /// Creates a [Fragment] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory Fragment.fromParts(List<Object> parts) =>
      Fragment(_combineParts(parts));
}

/// A piece of code representing a syntactically valid Declaration.
class Declaration extends Code {
  @override
  final String code;

  Declaration._(this.code);

  factory Declaration(String content) {
    // TODO: parse declarations, analyzer doesn't provide a nice api for this
    // that I can find.
    return Declaration._(content);
  }

  /// Creates a [Declaration] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory Declaration.fromParts(List<Object> parts) =>
      Declaration(_combineParts(parts));
}

/// A piece of code representing a syntactically valid Element.
class Element extends Code {
  @override
  final String code;

  Element._(this.code);

  factory Element(String content) {
    // TODO: parse elements, analyzer doesn't provide a nice api for this
    // that I can find.
    return Element._(content);
  }

  /// Creates a [Declaration] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory Element.fromParts(List<Object> parts) =>
      Element(_combineParts(parts));
}

/// A piece of code representing a syntactically valid Expression.
class Expression extends Code {
  ast.Expression _expression;

  @override
  String get code => _expression.toSource();

  Expression._(this._expression);

  factory Expression(String content) {
    var expr = _withParserAndToken(
        content, (parser, token) => parser.parseExpression(token));
    return Expression._(expr);
  }

  /// Creates an [Expression] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory Expression.fromParts(List<Object> parts) =>
      Expression(_combineParts(parts));
}

/// A piece of code representing a syntactically valid function body.
///
/// This includes any and all code after the parameter list of a function,
/// including modifiers like `async`.
///
/// Both arrow and block function bodies are allowed.
class FunctionBody extends Code {
  ast.FunctionBody _body;

  @override
  String get code => _body.toSource();

  FunctionBody._(this._body);

  factory FunctionBody(String content) {
    var body = _withParserAndToken(
        content,
        (parser, _) => parser.parseFunctionBody(
            false, ParserErrorCode.EXPECTED_BODY, false));
    return FunctionBody._(body);
  }

  /// Creates an [Expression] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory FunctionBody.fromParts(List<Object> parts) =>
      FunctionBody(_combineParts(parts));
}

/// A piece of code identifying a named argument.
///
/// This should not include any trailing commas.
class NamedArgument extends Code {
  @override
  final String code;

  NamedArgument._(this.code);

  factory NamedArgument(String content) {
    // TODO: parse declarations, analyzer doesn't provide a nice api for this
    // that I can find.
    return NamedArgument._(content);
  }

  /// Creates a [Parameter] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory NamedArgument.fromParts(List<Object> parts) =>
      NamedArgument(_combineParts(parts));
}

/// A piece of code identifying a syntactically valid function parameter.
///
/// This should not include any trailing commas, but may include modifiers
/// such as `required`, and default values.
///
/// There is no distinction here made between named and positional params,
/// nore between optional or required params. It is the job of the user to
/// construct and combine these together in a way that creates valid parameter
/// lists.
class Parameter extends Code {
  @override
  final String code;

  Parameter._(this.code);

  factory Parameter(String content) {
    // TODO: parse declarations, analyzer doesn't provide a nice api for this
    // that I can find.
    return Parameter._(content);
  }

  /// Creates a [Parameter] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory Parameter.fromParts(List<Object> parts) =>
      Parameter(_combineParts(parts));
}

/// A piece of code representing a syntactically valid statement.
class Statement extends Code {
  ast.Statement _statement;

  @override
  String get code => _statement.toSource();

  Statement._(this._statement);

  factory Statement(String content) {
    var stmt = _withParserAndToken(
        content, (parser, token) => parser.parseStatement(token));
    return Statement._(stmt);
  }

  /// Creates a [Statement] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory Statement.fromParts(List<Object> parts) =>
      Statement(_combineParts(parts));
}

/// A piece of code representing a syntactically valid type annotation.
class TypeAnnotation extends Code {
  ast.TypeAnnotation _typeAnnotation;

  @override
  String get code => _typeAnnotation.toSource();

  TypeAnnotation._(this._typeAnnotation);

  factory TypeAnnotation(String content) {
    var typeAnnotation = _withParserAndToken(
        content,
        // TODO: exact implications of passing `false` here?
        (parser, token) => parser.parseTypeAnnotation(false));
    return TypeAnnotation._(typeAnnotation);
  }

  /// Creates a [TypeAnnotation] from [parts], which must be of type [Code]
  /// [List<Code>] or [String].
  ///
  /// When a [List<Code>] is encountered they are joined by a comma.
  factory TypeAnnotation.fromParts(List<Object> parts) =>
      TypeAnnotation(_combineParts(parts));
}

final _featureSet = FeatureSet.latestLanguageVersion();

T _withParserAndToken<T>(
    String content, T Function(Parser parser, Token token) fn) {
  var source = StringSource(content, '');
  var reader = CharSequenceReader(content);
  var errorCollector = RecordingErrorListener();
  var scanner = Scanner(source, reader, errorCollector)
    ..configureFeatures(
      featureSetForOverriding: _featureSet,
      featureSet: _featureSet,
    );
  var token = scanner.tokenize();
  var parser = Parser(
    source,
    errorCollector,
    featureSet: scanner.featureSet,
  );
  parser.currentToken = token;
  return fn(parser, token);
}

/// Combines [parts] into a [String]. Must only contain [Code] or [String]
/// instances.
String _combineParts(List<Object> parts) {
  var buffer = StringBuffer();
  for (var part in parts) {
    if (part is String) {
      buffer.write(part);
    } else if (part is Code) {
      buffer.write(part.code);
    } else if (part is List<Code>) {
      buffer.write(part.map((p) => p.code).join(', '));
    } else {
      throw UnsupportedError(
          'Only String, Code, and List<Code> are allowed but got $part');
    }
  }
  return buffer.toString();
}

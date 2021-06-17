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

  String toString() => code;
}

/// A piece of code that can't be parsed into a valid language construct in its
/// current form. No validation or parsing is performed.
class Fragment extends Code {
  final String code;

  Fragment(this.code);
}

class Block extends Code {
  final String code;

  Block._(this.code);

  factory Block(String content) {
    // TODO: parse blocks, analyzer doesn't provide a nice api for this
    // that I can find.
    return Block._(content);
  }

  /// Creates a [Block] from [parts], which must be [Code] objects or
  /// [String]s.
  factory Block.fromParts(List<Object> parts) => Block(_combineParts(parts));
}

/// A piece of code identifying a syntactically valid Declaration.
class Declaration extends Code {
  final String code;

  Declaration._(this.code);

  factory Declaration(String content) {
    // TODO: parse declarations, analyzer doesn't provide a nice api for this
    // that I can find.
    return Declaration._(content);
  }

  /// Creates a [Declaration] from [parts], which must be [Code] objects or
  /// [String]s.
  factory Declaration.fromParts(List<Object> parts) =>
      Declaration(_combineParts(parts));
}

class Expression extends Code {
  ast.Expression _expression;

  String get code => _expression.toSource();

  Expression._(this._expression);

  factory Expression(String content) {
    var expr = _withParserAndToken(
        content, (parser, token) => parser.parseExpression(token));
    return Expression._(expr);
  }

  /// Creates an [Expression] from [parts], which must be [Code] objects or
  /// [String]s.
  factory Expression.fromParts(List<Object> parts) =>
      Expression(_combineParts(parts));
}

class FunctionBody extends Code {
  ast.FunctionBody _body;

  String get code => _body.toSource();

  FunctionBody._(this._body);

  factory FunctionBody(String content) {
    var body = _withParserAndToken(
        content,
        (parser, _) => parser.parseFunctionBody(
            false, ParserErrorCode.EXPECTED_BODY, false));
    return FunctionBody._(body);
  }

  /// Creates an [Expression] from [parts], which must be [Code] objects or
  /// [String]s.
  factory FunctionBody.fromParts(List<Object> parts) =>
      FunctionBody(_combineParts(parts));
}

/// A piece of code identifying a reference to an identifier.
class Reference extends Code {
  final String code;

  Reference._(this.code);

  factory Reference(String content) {
    // TODO: parse references, analyzer doesn't provide a nice api for this
    // that I can find.
    return Reference._(content);
  }

  /// Creates a [Reference] from [parts], which must be [Code] objects or
  /// [String]s.
  factory Reference.fromParts(List<Object> parts) =>
      Reference(_combineParts(parts));
}

class Statement extends Code {
  ast.Statement _statement;

  String get code => _statement.toSource();

  Statement._(this._statement);

  factory Statement(String content) {
    var stmt = _withParserAndToken(
        content, (parser, token) => parser.parseStatement(token));
    return Statement._(stmt);
  }

  /// Creates a [Statement] from [parts], which must be [Code] objects or
  /// [String]s.
  factory Statement.fromParts(List<Object> parts) =>
      Statement(_combineParts(parts));
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
    } else {
      throw UnsupportedError(
          'Only String, Code, and Fragement are allowed but got $part');
    }
  }
  return buffer.toString();
}

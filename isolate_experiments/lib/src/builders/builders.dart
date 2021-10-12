import 'package:macro_builder/definition.dart';

class GenericBuilder {
  final builtCode = <String>[];

  @override
  void noSuchMethod(Invocation invocation) {
    var memberName = invocation.memberName.toString();
    memberName = memberName.substring(
        'Symbol("'.length, memberName.length - '")'.length);
    var output = StringBuffer('$memberName(');
    for (var arg in invocation.positionalArguments) {
      output.writeln('  $arg,');
    }
    if (invocation.namedArguments.isNotEmpty) {
      output.writeln('  {');
      for (var named in invocation.namedArguments.entries) {
        output.writeln('    ${named.key}: ${named.value},');
      }
      output.writeln('  }');
    }
    output.writeln(')');
    builtCode.add(output.toString());
  }
}

class GenericTypeBuilder extends GenericBuilder implements TypeBuilder {}

class GenericDeclarationBuilder extends GenericBuilder
    implements DeclarationBuilder {}

class GenericClassDeclarationBuilder extends GenericBuilder
    implements ClassDeclarationBuilder {}

class GenericConstructorDefinitionBuilder extends GenericBuilder
    implements ConstructorDefinitionBuilder {}

class GenericFunctionDefinitionBuilder extends GenericBuilder
    implements FunctionDefinitionBuilder {}

class GenericFieldDefinitionBuilder extends GenericBuilder
    implements FieldDefinitionBuilder {}

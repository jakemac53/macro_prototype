import 'package:macro_builder/macro_builder.dart';

const widgetMacro = _FunctionalWidget();

class _FunctionalWidget implements FunctionDeclarationMacro {
  final String? widgetName;

  const _FunctionalWidget(
      {
      // Defaults to removing the `_` and calling `toUpperCase` on the next
      // character.
      this.widgetName});

  @override
  void visitFunctionDeclaration(
      FunctionDeclaration declaration, DeclarationBuilder builder) {
    if (!declaration.name.startsWith('_')) {
      throw ArgumentError(
          'FunctionalWidget should only be used on private declarations');
    }
    if (declaration.positionalParameters.isEmpty ||
        declaration.positionalParameters.first.type.name != 'BuildContext') {
      throw ArgumentError(
          'FunctionalWidget functions must have a BuildContext argument as the '
          'first positional argument');
    }
    var widgetName = this.widgetName ??
        declaration.name.replaceRange(0, 2, declaration.name[1].toUpperCase());
    var positionalFieldParams = declaration.positionalParameters.skip(1);
    var fields = <Code>[
      for (var param in positionalFieldParams)
        Declaration('final ${param.type.toCode()} ${param.name};'),
      for (var param in declaration.namedParameters.values)
        Declaration('final ${param.type.toCode()} ${param.name};'),
    ];
    var constructorArgs = <Code>[
      for (var param in positionalFieldParams) Fragment('this.${param.name}, '),
      Fragment('{'),
      for (var param in declaration.namedParameters.values)
        Fragment('${param.required ? 'required ' : ''}this.${param.name}, '),
      Fragment('Key? key, }'),
    ];
    var constructor = Declaration.fromParts(
        ['const $widgetName(', ...constructorArgs, ') : super(key: key);']);
    var invocationArgs = <Code>[
      for (var param in positionalFieldParams) Fragment('${param.name}, '),
      for (var param in declaration.namedParameters.values)
        Fragment('${param.name}: ${param.name}, '),
    ];
    var buildMethod = Declaration.fromParts([
      '''
@override
Widget build(BuildContext context) =>
    ${declaration.name}(context, ''',
      ...invocationArgs,
      ');',
    ]);

    builder.addToLibrary(Declaration.fromParts([
      'class $widgetName extends StatelessWidget {',
      ...fields,
      constructor,
      buildMethod,
      '}',
    ]));
  }
}

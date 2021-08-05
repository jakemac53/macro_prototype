import 'package:macro_builder/definition.dart';
import 'package:collection/collection.dart';

const autoListenable = AutoListenable();

class AutoListenable implements ClassDeclarationMacro, MethodDefinitionMacro {
  const AutoListenable();

  /// In this phase we add overrides to all desired methods and apply ourself
  /// to them.
  @override
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder) {
    // TODO: https://github.com/jakemac53/macro_prototype/issues/33
    if (!declaration.hackyIsSubtypeOf('State')) {
      throw ArgumentError('@autoListenable can only be used on State classes');
    }
    var widgetClass = declaration.widgetClass;

    if (declaration.initState == null) {
      builder.addToClass(Declaration('''
@override
@autoListenable
external void initState();
'''));
    } else {
      // https://github.com/jakemac53/macro_prototype/issues/34
      throw ArgumentError(
          '@autoListenable isn\'t compatible with a custom `initState` '
          'method.');
    }

    if (declaration.didUpdateWidget == null) {
      builder.addToClass(Declaration.fromParts([
        '''
@override
@autoListenable
external void didUpdateWidget(
  ''',
        widgetClass.reference,
        ' oldWidget);'
      ]));
    } else {
      // https://github.com/jakemac53/macro_prototype/issues/34
      throw ArgumentError(
          '@autoListenable isn\'t compatible with a custom `didUpdateWidget` '
          'method.');
    }

    if (declaration.dispose == null) {
      builder.addToClass(Declaration('''
@override
@autoListenable
external void dispose();
'''));
    } else {
      // https://github.com/jakemac53/macro_prototype/issues/34, we comment
      // this check out for now and manually add a macro application in the\
      // user code.
      //
      // throw ArgumentError(
      //     '@autoListenable isn\'t compatible with a custom `dispose` method.');
    }
  }

  /// Here we actually implement each method, by looking at the fields on the
  /// widget class.
  @override
  void visitMethodDefinition(
      MethodDefinition definition, FunctionDefinitionBuilder builder) {
    var widgetClass = definition.definingClass.widgetClass;

    switch (definition.name) {
      case 'initState':
        _buildInitState(definition, widgetClass, builder);
        break;
      case 'didUpdateWidget':
        _buildDidUpdateWidget(definition, widgetClass, builder);
        break;
      case 'dispose':
        _buildDispose(definition, widgetClass, builder);
        break;
    }
  }

  void _buildInitState(MethodDefinition definition,
      ClassDeclaration widgetClass, FunctionDefinitionBuilder builder) {
    var statements = [
      if (definition.isExternal) Statement('super.initState();'),
    ];
    for (var field in widgetClass.fields) {
      // TODO: https://github.com/jakemac53/macro_prototype/issues/33
      if (!field.type.hackyIsSubtypeOf('Listenable')) continue;
      var handler = _handler(field, definition.definingClass, widgetClass);
      var questionMark = field.type.isNullable ? '?' : '';
      statements.add(Statement(
          'widget.${field.name}$questionMark.addListener($handler);'));
    }
    if (definition.isExternal) {
      builder.implement(FunctionBody.fromParts(['{', statements, '}']));
    } else {
      builder.wrapBody(after: statements);
    }
  }

  void _buildDidUpdateWidget(MethodDefinition definition,
      ClassDeclaration widgetClass, FunctionDefinitionBuilder builder) {
    var parts = <Statement>[
      if (definition.isExternal) Statement('super.didUpdateWidget(oldWidget);'),
    ];
    for (var field in widgetClass.fields) {
      // TODO: https://github.com/jakemac53/macro_prototype/issues/33
      if (!field.type.hackyIsSubtypeOf('Listenable')) continue;
      var handler = _handler(field, definition.definingClass, widgetClass);
      var questionMark = field.type.isNullable ? '?' : '';
      var widgetField = Fragment('widget.${field.name}$questionMark');
      var oldWidgetField = Fragment('oldWidget.${field.name}$questionMark');
      parts.add(Statement.fromParts([
        'if ($widgetField != $oldWidgetField) {',
        Statement('$oldWidgetField.removeListener($handler);'),
        Statement('$widgetField.addListener($handler);'),
        '}'
      ]));
    }
    if (definition.isExternal) {
      builder.implement(FunctionBody.fromParts(['{', parts, '}']));
    } else {
      builder.wrapBody(after: parts);
    }
  }

  void _buildDispose(MethodDefinition definition, ClassDeclaration widgetClass,
      FunctionDefinitionBuilder builder) {
    var parts = <Statement>[
      Statement('super.dispose();'),
    ];
    for (var field in widgetClass.fields) {
      // TODO: https://github.com/jakemac53/macro_prototype/issues/33
      if (!field.type.hackyIsSubtypeOf('Listenable')) continue;
      var handler = _handler(field, definition.definingClass, widgetClass);
      var questionMark = field.type.isNullable ? '?' : '';
      parts.add(Statement(
          'widget.${field.name}$questionMark.removeListener($handler);'));
    }
    if (definition.isExternal) {
      builder.implement(FunctionBody.fromParts(['{', parts, '}']));
    } else {
      builder.wrapBody(after: parts);
    }
  }

  /// Returns the expected handler name for [field], and throws if that handler
  /// does not exist on [stateClass].
  String _handler(FieldDeclaration field, ClassDeclaration stateClass,
      ClassDeclaration widgetClass) {
    var handlerName =
        '_handle${field.name[0].toUpperCase()}${field.name.substring(1)}';
    var handler =
        stateClass.methods.firstWhereOrNull((m) => m.name == handlerName);
    if (handler == null) {
      throw ArgumentError('Missing handler function `$handler` in '
          '${stateClass.name} for listenable field '
          '${field.name} from widget class ${widgetClass.name}.');
    }
    if (handler.positionalParameters.where((p) => p.required).isNotEmpty ||
        handler.namedParameters.values.where((p) => p.required).isNotEmpty) {
      throw ArgumentError(
          'Handler ${handler.name} did not match the expected signature, it '
          'should have no required parameters.');
    }
    return handlerName;
  }
}

extension on ClassDeclaration {
  MethodDeclaration? get initState =>
      methods.firstWhereOrNull((m) => m.name == 'initState');

  MethodDeclaration? get didUpdateWidget =>
      methods.firstWhereOrNull((m) => m.name == 'didUpdateWidget');

  MethodDeclaration? get dispose =>
      methods.firstWhereOrNull((m) => m.name == 'dispose');
}

extension on TypeDeclaration {
  bool hackyIsSubtypeOf(String type) {
    if (name == type) return true;
    if (this is ClassDeclaration) {
      for (var interface in (this as ClassDeclaration).superinterfaces) {
        if (interface.name == type) return true;
      }
    }
    return false;
  }
}

extension on ClassDeclaration {
  ClassDeclaration get widgetClass {
    ClassDeclaration next = this;
    while (true) {
      if (next.name == 'State') {
        return next.typeArguments.first as ClassDeclaration;
      }
      var superClass = next.superclass;
      if (superClass == null) {
        throw StateError('Unable to find widget class for state class $name');
      }
      next = superClass;
    }
  }
}

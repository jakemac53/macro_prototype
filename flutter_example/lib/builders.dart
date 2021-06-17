import 'package:build/build.dart';
import 'package:macro_builder/macro_builder.dart';

import 'macros/annotations.dart';
import 'macros/auto_dispose.dart';
import 'macros/functional_widget.dart';

Builder typesBuilder(_) => TypesMacroBuilder.forSpecialAnnotation({});
Builder declarationsBuilder(_) =>
    DeclarationsMacroBuilder.forSpecialAnnotation({
      widget: widgetMacro,
      autoDispose: autoDisposeMacro,
    });
Builder definitionsBuilder(_) => DefinitionsMacroBuilder.forSpecialAnnotation({
      autoDispose: autoDisposeMacro,
    });

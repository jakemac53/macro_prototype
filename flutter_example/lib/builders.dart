import 'package:build/build.dart';
import 'package:macro_builder/macro_builder.dart';

import 'macros/annotations.dart';
import 'macros/functional_widget.dart';

Builder typesBuilder(_) => TypesMacroBuilder.forSpecialAnnotation({});
Builder declarationsBuilder(_) =>
    DeclarationsMacroBuilder.forSpecialAnnotation({widget: widgetMacro});
Builder definitionsBuilder(_) =>
    DefinitionsMacroBuilder.forSpecialAnnotation({});

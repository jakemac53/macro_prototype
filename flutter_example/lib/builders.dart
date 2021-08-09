import 'package:build/build.dart';
import 'package:macro_builder/builder.dart';

import 'macros/auto_dispose.dart';
import 'macros/auto_listenable.dart';
import 'macros/functional_widget.dart';
import 'macros/render_accessors.dart';

Builder typesBuilder(_) => TypesMacroBuilder([fwidget]);
Builder declarationsBuilder(_) => DeclarationsMacroBuilder(
    [autoDispose, const RenderAccessors(), autoListenable]);
Builder definitionsBuilder(_) =>
    DefinitionsMacroBuilder([autoDispose, autoListenable]);

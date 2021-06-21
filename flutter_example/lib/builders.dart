import 'package:build/build.dart';
import 'package:macro_builder/builder.dart';

import 'macros/auto_dispose.dart';
import 'macros/functional_widget.dart';

Builder typesBuilder(_) => TypesMacroBuilder([]);
Builder declarationsBuilder(_) =>
    DeclarationsMacroBuilder([widget, autoDispose]);
Builder definitionsBuilder(_) => DefinitionsMacroBuilder([autoDispose]);

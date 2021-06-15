import 'package:build/build.dart';
import 'package:macro_builder/macro_builder.dart';

Builder typesBuilder(_) => TypesMacroBuilder([]);
Builder declarationsBuilder(_) => DeclarationsMacroBuilder([]);
Builder definitionsBuilder(_) => DefinitionsMacroBuilder([]);

import 'package:build/build.dart';
import 'package:macro_builder/builder.dart';

import 'macros/data_class.dart';
import 'macros/json.dart';
import 'macros/observable.dart';

Builder typesBuilder(_) => TypesMacroBuilder([]);
Builder declarationsBuilder(_) =>
    DeclarationsMacroBuilder([jsonSerializable, observable, dataClass]);
Builder definitionsBuilder(_) => DefinitionsMacroBuilder([jsonSerializable]);

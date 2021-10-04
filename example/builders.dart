import 'package:build/build.dart';
import 'package:macro_builder/builder.dart';

import 'package:macro_builder/macros/data_class.dart';
import 'package:macro_builder/macros/freezed.dart';
import 'package:macro_builder/macros/json.dart';
import 'package:macro_builder/macros/observable.dart';

Builder typesBuilder(_) => TypesMacroBuilder([]);
Builder declarationsBuilder(_) {
  return DeclarationsMacroBuilder(
    [freezed, jsonSerializable, observable, dataClass],
  );
}

Builder definitionsBuilder(_) => DefinitionsMacroBuilder([jsonSerializable]);

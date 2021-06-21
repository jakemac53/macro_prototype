import 'src/types.dart';

export 'src/code.dart';
export 'src/declarations.dart';
export 'src/definitions.dart';
export 'src/macro.dart';
export 'src/types.dart';

extension ToCode on TypeReference {
  // Recreates a string for the type declaration `d`, with type arguments if
  // present as well as retaining `?` markers.
  String toCode() {
    var type = StringBuffer(name);
    if (typeArguments.isNotEmpty) {
      type.write('<');
      var types = [];
      for (var typeArg in typeArguments) {
        types.add(typeArg.toCode());
      }
      type.write(types.join(', '));
      type.write('>');
    }
    if (isNullable) type.write('?');
    return type.toString();
  }
}

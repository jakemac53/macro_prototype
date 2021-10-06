import 'dart:async';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:graphs/graphs.dart';
import 'package:package_config/package_config.dart';

import 'src/driver.dart';

void main() async {
  var pkgConfig = await findPackageConfig(io.Directory.current);
  if (pkgConfig == null) {
    throw StateError(
        'Unable to load package config, run `dart pub get` and ensure '
        'you are running from the package root.');
  }
  var driver = await analysisDriver(pkgConfig);
  var localLibs = await _findLocalLibraryUris().toList();
  var allLibraries = (await crawlAsync<Uri, SomeResolvedLibraryResult>(
    localLibs,
    (Uri uri) async => (await driver.getResolvedLibraryByUri2(uri)),
    (Uri uri, SomeResolvedLibraryResult result) =>
        result is ResolvedLibraryResult
            ? result.element.importedLibraries
                .followedBy(result.element.exportedLibraries)
                .map((library) => library.source.uri)
            : const Iterable.empty(),
  ).toList())
      .whereType<ResolvedLibraryResult>()
      .toList();
  var macroClass = allLibraries
      .firstWhere(
          (l) => l.uri == Uri.parse('package:macro_builder/src/macro.dart'))
      .element
      .getType('Macro')!;
  for (var lib in allLibraries.reversed) {
    var macros = _discoverMacros(lib.element, macroClass.thisType);
    print('Loading macros $macros from ${lib.uri}');
  }
}

Stream<Uri> _findLocalLibraryUris() async* {
  await for (var entity in io.Directory('lib').list(recursive: true)) {
    if (entity is! io.File) continue;
    yield entity.absolute.uri;
  }
}

List<ClassElement> _discoverMacros(LibraryElement library, DartType macroType) {
  var macros = <ClassElement>[];
  var typeSystem = library.typeSystem;
  for (var clazz in library.topLevelElements.whereType<ClassElement>()) {
    if (clazz.isAbstract) continue;
    if (typeSystem.isSubtypeOf(clazz.thisType, macroType)) {
      macros.add(clazz);
    }
  }
  return macros;
}

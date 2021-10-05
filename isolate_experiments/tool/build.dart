import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:graphs/graphs.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

import 'src/driver.dart';
import 'src/resource_provider.dart';
import 'src/uri_resolver.dart';

void main() async {
  var pkgConfig = await findPackageConfig(Directory.current);
  if (pkgConfig == null) {
    throw StateError(
        'Unable to load package config, run `dart pub get` and ensure '
        'you are running from the package root.');
  }
  var resolver =
      CustomUriResolver(pkgConfig, CustomResourceProvider(pkgConfig));
  var driver = await analysisDriver(resolver, pkgConfig);

  var allLibraries = (await crawlAsync<Uri, SomeResolvedLibraryResult>(
    await _findLocalLibraryUris(driver, resolver).toList(),
    (Uri uri) async => (await driver.getResolvedLibraryByUri2(uri)),
    (Uri uri, SomeResolvedLibraryResult result) => result
            is ResolvedLibraryResult
        ? result.element.importedLibraries.map((library) => library.source.uri)
        : const Iterable.empty(),
  ).toList())
      .whereType<ResolvedLibraryResult>();
  var librariesByUri = {
    for (var lib in allLibraries) lib.uri: lib,
  };
  var components = stronglyConnectedComponents(
      allLibraries,
      (ResolvedLibraryResult root) => root.element.importedLibraries
          .map((imported) => librariesByUri[imported.source.uri])
          .whereType<ResolvedLibraryResult>(),
      equals: (ResolvedLibraryResult a, ResolvedLibraryResult b) =>
          a.uri == b.uri,
      hashCode: (ResolvedLibraryResult a) => a.uri.hashCode);
  for (var component in components) {
    print('libraries:');
    for (var library in component) {
      print('- ${library.uri}:');
    }
  }
}

Stream<Uri> _findLocalLibraryUris(
    AnalysisDriver driver, CustomUriResolver uriResolver) async* {
  await for (var entity in Directory('lib').list(recursive: true)) {
    if (entity is! File) continue;
    var resolved = uriResolver.normalize(entity.absolute.uri);
    if (resolved == null) continue;
    yield resolved;
  }
}

// class MacroVisitor extends RecursiveElementVisitor {
//   @override
//   void visitClassElement(ClassElement element) {
//     element.visitChildren(this);
//     for (var annotation in element.metadata) {
//       var value = annotation.computeConstantValue();
//       if (value?.type == null) {
//         throw StateError(
//             'unable to compute annotation ${annotation.toSource()}');
//       }
//       if (element.library.typeSystem.isAssignableTo(leftType, value!.type!)) {}
//     }
//   }
// }

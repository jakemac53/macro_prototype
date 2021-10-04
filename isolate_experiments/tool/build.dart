import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/driver.dart';
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

  await for (var library in _findLibraries(driver)) {
    print(library.toString());
  }
}

Stream<ResolvedLibraryResult> _findLibraries(AnalysisDriver driver) async* {
  await for (var entity in Directory('lib').list(recursive: true)) {
    if (entity is! File) continue;
    yield await driver.getResolvedLibraryByUri2(Uri(
            scheme: 'asset', path: p.join('/isolate_experiments', entity.path)))
        as ResolvedLibraryResult;
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/file_system.dart' show ResourceProvider;
import 'package:analyzer/file_system/physical_file_system.dart'
    show PhysicalResourceProvider;
// ignore: implementation_imports
import 'package:analyzer/src/context/packages.dart' show Packages, Package;
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/byte_store.dart'
    show MemoryByteStore;
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/driver.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/performance_logger.dart'
    show PerformanceLog;
// ignore: implementation_imports
import 'package:analyzer/src/generated/engine.dart' show AnalysisOptionsImpl;
// ignore: implementation_imports
import 'package:analyzer/src/generated/source.dart';
// ignore: implementation_imports
import 'package:analyzer/src/summary/package_bundle_reader.dart';
// ignore: implementation_imports
import 'package:analyzer/src/summary/summary_sdk.dart' show SummaryBasedDartSdk;
import 'package:package_config/package_config.dart' show PackageConfig;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'uri_resolver.dart';

/// Builds an [AnalysisDriver] backed by a summary SDK and package summary
/// files.
///
/// Any code which is not covered by the summaries must be resolvable through
/// [uriResolver].
Future<AnalysisDriver> analysisDriver(
  CustomUriResolver uriResolver,
  PackageConfig packageConfig,
) async {
  var sdkSummaryPath = await _generateSdkSummary();
  var sdk = SummaryBasedDartSdk(sdkSummaryPath, true);
  var dataStore = SummaryDataStore([sdkSummaryPath]);

  var sdkResolver = DartUriResolver(sdk);
  var resolvers = [sdkResolver, uriResolver];
  var sourceFactory = SourceFactory(resolvers);

  var logger = PerformanceLog(null);
  var scheduler = AnalysisDriverScheduler(logger);

  var packages =
      _buildAnalyzerPackages(packageConfig, uriResolver.resourceProvider);
  var options = AnalysisOptionsImpl()
    ..contextFeatures = FeatureSet.fromEnableFlags2(
        sdkLanguageVersion: sdkLanguageVersion, flags: const []);
  var driver = AnalysisDriver.tmp1(
      scheduler: scheduler,
      logger: logger,
      resourceProvider: uriResolver.resourceProvider,
      byteStore: MemoryByteStore(),
      sourceFactory: sourceFactory,
      analysisOptions: options,
      externalSummaries: dataStore,
      packages: packages);

  scheduler.start();
  return driver;
}

Packages _buildAnalyzerPackages(
        PackageConfig packageConfig, ResourceProvider resourceProvider) =>
    Packages({
      for (var package in packageConfig.packages)
        package.name: Package(
            name: package.name,
            languageVersion: package.languageVersion == null
                ? sdkLanguageVersion
                : Version(package.languageVersion!.major,
                    package.languageVersion!.minor, 0),
            // Analyzer does not see the original file paths at all, we need to
            // make them match the paths that we give it.
            rootFolder: resourceProvider.getFolder('/${package.name}'),
            libFolder:
                resourceProvider.getFolder(p.join('/${package.name}', 'lib'))),
    });

/// The language version of the current sdk parsed from the [Platform.version].
final sdkLanguageVersion = () {
  var sdkVersion = Version.parse(Platform.version.split(' ').first);
  return Version(sdkVersion.major, sdkVersion.minor, 0);
}();

/// Lazily creates a summary of the users SDK and caches it under
/// `.dart_tool/macro_prototype`.
///
/// This is only intended for use in typical dart packages, which must
/// have an already existing `.dart_tool` directory (this is how we
/// validate we are running under a typical dart package and not a custom
/// environment).
Future<String> _generateSdkSummary() async {
  var dartToolPath = '.dart_tool';
  if (!await Directory(dartToolPath).exists()) {
    throw StateError(
        'This tool can only be ran from the `isolate_experiments` directory');
  }

  var cacheDir = p.join(dartToolPath, 'macro_prototype');
  var summaryPath = p.join(cacheDir, 'sdk.sum');
  var depsFile = File('$summaryPath.deps');
  var summaryFile = File(summaryPath);

  var currentDeps = {
    'sdk': Platform.version,
    for (var package in _packageDepsToCheck)
      package: await _packagePath(package),
  };

  // Invalidate existing summary/version/analyzer files if present.
  if (await depsFile.exists()) {
    if (!await _checkDeps(depsFile, currentDeps)) {
      await depsFile.delete();
      if (await summaryFile.exists()) await summaryFile.delete();
    }
  } else if (await summaryFile.exists()) {
    // Fallback for cases where we could not do a proper version check.
    await summaryFile.delete();
  }

  // Generate the summary and version files if necessary.
  if (!await summaryFile.exists()) {
    var watch = Stopwatch()..start();
    print('Generating SDK summary...');
    await summaryFile.create(recursive: true);
    final embedderYamlPath =
        _isFlutter ? p.join(_dartUiPath, '_embedder.yaml') : null;
    await summaryFile.writeAsBytes(buildSdkSummary(
        sdkPath: _runningDartSdkPath,
        resourceProvider: PhysicalResourceProvider.INSTANCE,
        embedderYamlPath: embedderYamlPath));

    await _createDepsFile(depsFile, currentDeps);
    watch.stop();
    print('Generating SDK summary completed, took ${watch.elapsed}\n');
  }

  return p.absolute(summaryPath);
}

final _packageDepsToCheck = ['analyzer'];

Future<bool> _checkDeps(
    File versionsFile, Map<String, Object?> currentDeps) async {
  var previous =
      jsonDecode(await versionsFile.readAsString()) as Map<String, Object?>;

  if (previous.keys.length != currentDeps.keys.length) return false;

  for (var entry in previous.entries) {
    if (entry.value != currentDeps[entry.key]) return false;
  }

  return true;
}

Future<void> _createDepsFile(
    File depsFile, Map<String, Object?> currentDeps) async {
  await depsFile.create(recursive: true);
  await depsFile.writeAsString(jsonEncode(currentDeps));
}

/// Path where the dart:ui package will be found, if executing via the dart
/// binary provided by the Flutter SDK.
final _dartUiPath =
    p.normalize(p.join(_runningDartSdkPath, '..', 'pkg', 'sky_engine', 'lib'));

/// Path to the running dart's SDK root.
final _runningDartSdkPath = p.dirname(p.dirname(Platform.resolvedExecutable));

/// `true` if the currently running dart was provided by the Flutter SDK.
final _isFlutter =
    Platform.version.contains('flutter') || Directory(_dartUiPath).existsSync();

Future<String> _packagePath(String package) async {
  var libRoot = await Isolate.resolvePackageUri(Uri.parse('package:$package/'));
  return p.dirname(p.fromUri(libRoot));
}

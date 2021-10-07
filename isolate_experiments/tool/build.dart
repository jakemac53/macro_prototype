import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate' as isolate;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:graphs/graphs.dart';
import 'package:isolate_experiments/protocol.dart';
import 'package:package_config/package_config.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'src/driver.dart';

void main() async {
  _log('Generating isolate script');
  var tmpDir = await io.Directory.systemTemp.createTemp('macroIsolate');
  var macroIsolateFile = io.File('${tmpDir.path}/main.dart');
  await macroIsolateFile.writeAsString(_buildIsolateMain([]));

  _log('Spawning macro process');
  var macroProcess = await io.Process.start(io.Platform.executable, [
    '--packages=${await isolate.Isolate.packageConfig}',
    '--enable-vm-service',
    macroIsolateFile.uri.toString(),
  ]);
  _log('Waiting for initial response');
  macroProcess.stderr
      .transform(const Utf8Decoder())
      .transform(const LineSplitter())
      .listen(io.stderr.writeln);
  var lines = macroProcess.stdout
      .transform(const Utf8Decoder())
      .transform(const LineSplitter());
  var serviceCompleter = Completer<VmService>();
  Completer<RunMacroResponse>? nextResponseCompleter;
  lines.listen((line) {
    if (!serviceCompleter.isCompleted) {
      _log('Connecting to vm service');
      serviceCompleter.complete(vmServiceConnectUri(convertToWebSocketUrl(
              serviceProtocolUrl: Uri.parse(line.split(' ').last))
          .toString()));
    } else {
      if (!line.startsWith('The Dart DevTools debugger')) {
        if (nextResponseCompleter != null) {
          nextResponseCompleter!.complete(RunMacroResponse.fromJson(
              jsonDecode(line) as Map<String, Object?>));
          nextResponseCompleter = null;
        }
      }
    }
  });
  var vmService = await serviceCompleter.future;
  var rootIsolate = (await vmService.getVM()).isolates!.first;

  _log('Setting up analysis driver');
  var pkgConfig = await findPackageConfig(io.Directory.current);
  if (pkgConfig == null) {
    throw StateError(
        'Unable to load package config, run `dart pub get` and ensure '
        'you are running from the package root.');
  }
  var driver = await analysisDriver(pkgConfig);

  _log('Finding local libraries');
  var localLibs = await _findLocalLibraryUris().toList();

  _log('Finding all reachable transitive libraries');
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

  _log('Searching for macros');
  var allMacros = <ClassElement>[];
  for (var lib in allLibraries.reversed) {
    var macros = _discoverMacros(lib.element, macroClass.thisType);
    if (macros.isEmpty) continue;
    allMacros.addAll(macros);
    _log(
        'Loading macros ${macros.map((m) => m.name).toList()} from ${lib.uri}');
    await macroIsolateFile.writeAsString(_buildIsolateMain(allMacros));
    var reloadResult =
        await vmService.callMethod('reloadSources', isolateId: rootIsolate.id);
    _log('Reloaded: $reloadResult');
    for (var macro in macros) {
      _log('Sending macro request for ${macro.name}');
      nextResponseCompleter = Completer<RunMacroResponse>();
      macroProcess.stdin.writeln(
          jsonEncode(RunMacroRequest(_macroId(macro), const {}).toJson()));
      var response = await nextResponseCompleter!.future;
      _log('Macro response: ${response.generatedCode}');
    }
    _log('Done loading macros from ${lib.uri}');
  }
  _log('Exiting');
  await tmpDir.delete(recursive: true);
  macroProcess.kill();
}

Stream<Uri> _findLocalLibraryUris() async* {
  await for (var entity in io.Directory('lib').list(recursive: true)) {
    if (entity is! io.File) continue;
    yield entity.absolute.uri;
  }
}

String _buildIsolateMain(List<ClassElement> macros) {
  var importsAdded = <Uri>{};
  var code = StringBuffer(r'''
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:macro_builder/definition.dart';
import 'package:isolate_experiments/protocol.dart';
''');
  for (var macro in macros) {
    if (importsAdded.add(macro.librarySource.uri)) {
      code.writeln('import \'${macro.librarySource.uri}\';');
    }
  }

  code.writeln(r'''

Future<RunMacroResponse> _runMacro(RunMacroRequest request) async {
  Macro? macro; // Gets build in the switch
  switch (request.identifier) {''');

  for (var macro in macros) {
    // TODO: support arguments to constructors
    code.writeln('''
    case '${_macroId(macro)}':
      macro = const ${macro.name}();
      break;''');
  }

  code.writeln(r'''
    default:
      throw StateError('Unknown macro ${request.identifier}');
  }

  return RunMacroResponse('$macro');
}

void main(List<String> _) async {
  stdin.transform(const Utf8Decoder()).transform(const LineSplitter()).listen((line) async {
    var message = jsonDecode(line) as Map<String, Object?>;
    var response = await _runMacro(RunMacroRequest.fromJson(message));
    stdout.writeln(jsonEncode(response.toJson()));
  });
}
''');
  return code.toString();
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

final _watch = Stopwatch()..start();

void _log(String message) {
  print('${_watch.elapsed}: $message');
}

String _macroId(ClassElement macro) =>
    '${macro.librarySource.uri}#${macro.name}';

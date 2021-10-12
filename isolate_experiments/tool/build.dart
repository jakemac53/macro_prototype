import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate' as isolate;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:graphs/graphs.dart';
import 'package:isolate_experiments/protocol.dart';
import 'package:package_config/package_config.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'src/driver.dart';

void main() async {
  _log('Setting up analysis driver');
  var pkgConfig = await findPackageConfig(io.Directory.current);
  if (pkgConfig == null) {
    throw StateError(
        'Unable to load package config, run `dart pub get` and ensure '
        'you are running from the package root.');
  }
  var driver = await analysisDriver(pkgConfig);

  _log('Finding local libraries');
  var exampleLibs = await _findExampleLibraryUris().toList();

  _log('Finding all reachable transitive libraries');
  var allLibraries = await crawlAsync<Uri, SomeResolvedLibraryResult>(
    exampleLibs,
    (Uri uri) async => (await driver.getResolvedLibraryByUri2(uri)),
    (Uri uri, SomeResolvedLibraryResult result) =>
        result is ResolvedLibraryResult
            ? result.element.importedLibraries
                .followedBy(result.element.exportedLibraries)
                .map((library) => library.source.uri)
            : const Iterable.empty(),
  )
      .where((l) => l is ResolvedLibraryResult)
      .cast<ResolvedLibraryResult>()
      .toList();

  _log('Indexing libraries by uri');
  var librariesByUri = {
    for (var library in allLibraries) library.uri: library,
  };

  _log('Grouping libraries into strongly connected components');
  var libraryGroups = stronglyConnectedComponents(
      allLibraries,
      (ResolvedLibraryResult library) => [
            for (var dep in library.element.importedLibraries)
              if (librariesByUri.containsKey(dep.source.uri))
                librariesByUri[dep.source.uri]!
          ]);

  _log('Loading and applying macros');
  var macroLib =
      librariesByUri[Uri.parse('package:macro_builder/src/macro.dart')]!
          .element;
  var macroClass = macroLib.getType('Macro')!;
  var typeMacroClass = macroLib.getType('TypeMacro')!;
  var declarationMacroClass = macroLib.getType('DeclarationMacro')!;
  var definitionMacroClass = macroLib.getType('DefinitionMacro')!;

  _log('Initializing the macro execution library');
  var dartCore =
      (await driver.getLibraryByUri2('dart:core')) as LibraryElementResult;
  var macroExecutor = await _MacroExecutor.start((Uri uri) {
    if (uri.scheme == 'dart' && uri.path.startsWith('core')) {
      return dartCore.element;
    }
    var lib = librariesByUri[uri];
    if (lib == null) throw StateError('could not resolve $uri');
    return lib.element;
  });
  for (var group in libraryGroups) {
    await macroExecutor._applyMacros(
        group, typeMacroClass.thisType, Phase.type);
    await macroExecutor._applyMacros(
        group, declarationMacroClass.thisType, Phase.declaration);
    await macroExecutor._applyMacros(
        group, definitionMacroClass.thisType, Phase.definition);
    await macroExecutor._discoverAndLoadMacros(group, macroClass.thisType);
  }
  _log('Exiting');
  await macroExecutor.close();
}

class _MacroExecutor {
  final allMacros = <ClassElement>[];
  Completer<RunMacroResponse>? runMacroResponseCompleter;
  final io.File macroIsolateFile;
  final io.Process macroProcess;
  final LibraryElement Function(Uri) resolveLibrary;
  final Stream<String> responseStream;
  final IsolateRef rootIsolate;
  final io.Directory tmpDir;
  final VmService vmService;

  _MacroExecutor({
    required this.macroIsolateFile,
    required this.macroProcess,
    required this.resolveLibrary,
    required this.responseStream,
    required this.rootIsolate,
    required this.tmpDir,
    required this.vmService,
  }) {
    responseStream.listen((line) {
      var json = jsonDecode(line) as Map<String, Object?>;
      var type = json['type'] as String;
      switch (type) {
        case 'RunMacroResponse':
          if (runMacroResponseCompleter != null) {
            runMacroResponseCompleter!
                .complete(RunMacroResponse.fromJson(json));
            runMacroResponseCompleter = null;
          } else {
            throw StateError('Got an unexpected RunMacroResponse');
          }
          break;
        case 'ReflectTypeRequest':
          var request = ReflectTypeRequest.fromJson(json);

          DartType _resolveType(TypeReferenceDescriptor descriptor) {
            var library = resolveLibrary(Uri.parse(descriptor.libraryUri));
            var element = library.getType(descriptor.name);
            if (element == null) {
              throw StateError(
                  'Could not resolve ${descriptor.name} in ${descriptor.libraryUri}');
            }
            var typeArgs = [
              for (var arg in descriptor.typeArguments) _resolveType(arg),
            ];
            return element.instantiate(
                typeArguments: typeArgs,
                nullabilitySuffix: descriptor.isNullable
                    ? NullabilitySuffix.question
                    : NullabilitySuffix.none);
          }
          var type = _resolveType(request.descriptor);
          var declaration = SerializableClassDefinition.fromElement(
              type.element as ClassElement,
              originalReference: type);
          var response = ReflectTypeResponse(declaration);
          try {
            macroProcess.stdin.writeln(jsonEncode(response.toJson()));
          } catch (_) {
            var map = response.toJson();
            void _tryRecursive(Object? json, List<String> path) {
              try {
                jsonEncode(json);
              } catch (_) {
                if (json is Map) {
                  for (var entry in json.entries) {
                    _tryRecursive(entry.value, [...path, entry.key as String]);
                  }
                } else if (json is List) {
                  for (var i = 0; i < json.length; i++) {
                    _tryRecursive(json[i], [...path, i.toString()]);
                  }
                } else {
                  throw 'Failed to encode $json at ${path.join(' -> ')}';
                }
              }
            }

            _tryRecursive(map, []);
            rethrow;
          }
          break;
        default:
          throw StateError('unhandled response $line');
      }
    });
  }

  static Future<_MacroExecutor> start(
      LibraryElement Function(Uri) resolveLibrary) async {
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
    var responseController = StreamController<String>();
    lines.listen((line) {
      if (!serviceCompleter.isCompleted) {
        _log('Connecting to vm service');
        serviceCompleter.complete(vmServiceConnectUri(convertToWebSocketUrl(
                serviceProtocolUrl: Uri.parse(line.split(' ').last))
            .toString()));
      } else {
        if (!line.startsWith('The Dart DevTools debugger')) {
          responseController.add(line);
        }
      }
    }, onDone: responseController.close);
    var vmService = await serviceCompleter.future;
    _log('Waiting for macro isolate to be runnable');
    await vmService.streamListen('Isolate');
    final rootIsolate = (await vmService.onIsolateEvent.firstWhere((e) {
      return e.kind == 'IsolateRunnable';
    }))
        .isolate!;

    return _MacroExecutor(
        macroIsolateFile: macroIsolateFile,
        macroProcess: macroProcess,
        resolveLibrary: resolveLibrary,
        responseStream: responseController.stream,
        rootIsolate: rootIsolate,
        tmpDir: tmpDir,
        vmService: vmService);
  }

  Future<void> close() async {
    await tmpDir.delete(recursive: true);
    macroProcess.kill();
  }

  Future<void> _applyMacros(List<ResolvedLibraryResult> libraryCycle,
      DartType macroType, Phase phase) async {
    var typeSystem = libraryCycle.first.element.typeSystem;
    for (var library in libraryCycle) {
      var finder = _MacroApplicationFinder(macroType, typeSystem)
        ..visitLibraryElement(library.element);
      for (var match in finder.matches) {
        _log(
            'Sending macro request for ${match.annotation.toSource()} matching '
            'type ${macroType.getDisplayString(withNullability: false)} on '
            '${match.annotatedElement}');
        runMacroResponseCompleter = Completer<RunMacroResponse>();
        var macroClass = match.value.type as InterfaceType;
        var appliedToClass = match.annotatedElement as ClassElement;
        var appliedToClassDefinition = SerializableClassDefinition.fromElement(
            appliedToClass,
            originalReference: appliedToClass.thisType);
        var request = RunMacroRequest(_macroId(macroClass.element),
            const <String, Object?>{}, appliedToClassDefinition, phase);
        macroProcess.stdin.writeln(jsonEncode(request.toJson()));
        var response = await runMacroResponseCompleter!.future;
        _log('Macro response: ${response.generatedCode}');
      }
    }
  }

  Future<List<ClassElement>> _discoverAndLoadMacros(
      List<ResolvedLibraryResult> libraryCycle, DartType macroType) async {
    var macros = <ClassElement>[];
    var typeSystem = libraryCycle.first.element.typeSystem;
    for (var library in libraryCycle) {
      for (var clazz
          in library.element.topLevelElements.whereType<ClassElement>()) {
        if (clazz.isAbstract) continue;
        if (typeSystem.isSubtypeOf(clazz.thisType, macroType)) {
          macros.add(clazz);
        }
      }
    }
    if (macros.isEmpty) return const [];
    allMacros.addAll(macros);

    _log('Loading macros ${macros.map((m) => m.name).toList()} from libraries: '
        '[${libraryCycle.map((lib) => lib.uri).join(', ')}]');
    await macroIsolateFile.writeAsString(_buildIsolateMain(allMacros));
    var reloadResult =
        await vmService.callMethod('reloadSources', isolateId: rootIsolate.id);
    _log('Isolate reloaded: $reloadResult');
    return macros;
  }
}

Stream<Uri> _findExampleLibraryUris() async* {
  await for (var entity in io.Directory('example').list(recursive: true)) {
    if (entity is! io.File) continue;
    yield entity.absolute.uri;
  }
}

String _buildIsolateMain(List<ClassElement> macros) {
  var importsAdded = <Uri>{};
  var code = StringBuffer(r'''
import 'dart:cli';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
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
  Macro? macro; // Gets built in the switch
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

  final declaration = request.declaration;
  late GenericBuilder builder;
  switch(request.phase) {
    case Phase.type:
      builder = GenericTypeBuilder();
      if (macro is ClassTypeMacro && declaration is ClassType) {
        macro.visitClassType(declaration as ClassType, builder as TypeBuilder);
      } else if (macro is FieldTypeMacro && declaration is FieldType) {
        macro.visitFieldType(declaration as FieldType, builder as TypeBuilder);
      } else if (macro is FunctionTypeMacro && declaration is FunctionType) {
        macro.visitFunctionType(declaration as FunctionType, builder as TypeBuilder);
      } else if (macro is MethodTypeMacro && declaration is MethodType) {
        macro.visitMethodType(declaration as MethodType, builder as TypeBuilder);
      } else if (macro is ConstructorTypeMacro && declaration is ConstructorType) {
        macro.visitConstructorType(declaration as ConstructorType, builder as TypeBuilder);
      } else {
        // TODO: Fix other side to check the declaration types
        // throw StateError('Unable to run $macro on $declaration');
      }
      break;
    case Phase.declaration:
      if (macro is ClassDeclarationMacro && declaration is ClassDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitClassDeclaration(declaration as ClassDeclaration, builder as ClassDeclarationBuilder);
      } else if (macro is FieldDeclarationMacro && declaration is FieldDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitFieldDeclaration(declaration as FieldDeclaration, builder as ClassDeclarationBuilder);
      } else if (macro is FunctionDeclarationMacro && declaration is FunctionDeclaration) {
        builder = GenericDeclarationBuilder();
        macro.visitFunctionDeclaration(declaration as FunctionDeclaration, builder as GenericDeclarationBuilder);
      } else if (macro is MethodDeclarationMacro && declaration is MethodDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitMethodDeclaration(declaration as MethodDeclaration, builder as ClassDeclarationBuilder);
      } else if (macro is ConstructorDeclarationMacro && declaration is ConstructorDeclaration) {
        builder = GenericClassDeclarationBuilder();
        macro.visitConstructorDeclaration(declaration as ConstructorDeclaration, builder as ClassDeclarationBuilder);
      } else {
        // TODO: Fix other side to check the declaration types
        builder = GenericTypeBuilder();
        // throw StateError('Unable to run $macro on $declaration');
      }
      break;
    case Phase.definition:
      if (macro is FieldDefinitionMacro && declaration is FieldDefinition) {
        builder = GenericFieldDefinitionBuilder();
        macro.visitFieldDefinition(declaration as FieldDefinition, builder as FieldDefinitionBuilder);
      } else if (macro is FunctionDefinitionMacro && declaration is FunctionDefinition) {
        builder = GenericFunctionDefinitionBuilder();
        macro.visitFunctionDefinition(declaration as FunctionDefinition, builder as FunctionDefinitionBuilder);
      } else if (macro is MethodDefinitionMacro && declaration is MethodDefinition) {
        builder = GenericFunctionDefinitionBuilder();
        macro.visitMethodDefinition(declaration as MethodDefinition, builder as FunctionDefinitionBuilder);
      } else if (macro is ConstructorDefinitionMacro && declaration is ConstructorDefinition) {
        builder = GenericConstructorDefinitionBuilder();
        macro.visitConstructorDefinition(declaration as ConstructorDefinition, builder as ConstructorDefinitionBuilder);
      } else {
        // TODO: Fix other side to check the declaration types
        builder = GenericTypeBuilder();
        // throw StateError('Unable to run $macro on $declaration');
      }
      break;
  }

  return RunMacroResponse(builder.builtCode.join('\n\n'));
}

ReflectTypeResponse<T> reflectTypeSync<T extends Serializable>(
        ReflectTypeRequest request) {
  stdout.writeln(jsonEncode(request.toJson()));
  var message = jsonDecode(waitFor(stdinLines.next)) as Map<String, Object?>;
  assert(message['type'] == 'ReflectTypeResponse');
  return ReflectTypeResponse<T>.fromJson(message);
}

final stdinLines = StreamQueue<String>(
    stdin.transform(const Utf8Decoder()).transform(const LineSplitter()));

void main(List<String> _) async {
  reflectType = reflectTypeSync;

  while (await stdinLines.hasNext) {
    var line = await stdinLines.next;
    var json = jsonDecode(line) as Map<String, Object?>;
    assert(json['type'] == 'RunMacroRequest');
    var request = RunMacroRequest.fromJson(json);
    var response = await _runMacro(request);
    stdout.writeln(jsonEncode(response.toJson()));
  }
}
''');
  return code.toString();
}

final _watch = Stopwatch()..start();

void _log(String message) {
  print('${_watch.elapsed}: $message');
}

String _macroId(ClassElement macro) =>
    '${macro.librarySource.uri}#${macro.name}';

class Match {
  final DartObject value;
  final ElementAnnotation annotation;
  final Element annotatedElement;

  Match(
      {required this.value,
      required this.annotatedElement,
      required this.annotation});
}

class _MacroApplicationFinder extends RecursiveElementVisitor {
  final List<Match> matches = [];
  final DartType matchingType;
  final TypeSystem typeSystem;

  _MacroApplicationFinder(this.matchingType, this.typeSystem);

  void _addMatchingAnnotations(Element element) {
    for (var annotation in element.metadata) {
      var value = annotation.computeConstantValue()!;
      if (typeSystem.isSubtypeOf(value.type!, matchingType)) {
        matches.add(Match(
            value: value, annotatedElement: element, annotation: annotation));
      }
    }
  }

  @override
  void visitClassElement(ClassElement element) {
    super.visitClassElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitConstructorElement(ConstructorElement element) {
    super.visitConstructorElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitExtensionElement(ExtensionElement element) {
    super.visitExtensionElement(element);
    // TODO: support extension macros
    // _addMatchingAnnotations(element);
  }

  @override
  visitFieldElement(FieldElement element) {
    super.visitFieldElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitFunctionElement(FunctionElement element) {
    super.visitFunctionElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitLocalVariableElement(LocalVariableElement element) {
    // TODO: implement visitLocalVariableElement
    throw UnimplementedError();
  }

  @override
  visitMethodElement(MethodElement element) {
    super.visitMethodElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitPropertyAccessorElement(PropertyAccessorElement element) {
    super.visitPropertyAccessorElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitTopLevelVariableElement(TopLevelVariableElement element) {
    super.visitTopLevelVariableElement(element);
    _addMatchingAnnotations(element);
  }

  @override
  visitTypeAliasElement(TypeAliasElement element) {
    super.visitTypeAliasElement(element);
    // TODO: support type alias macros?
    // _addMatchingAnnotations(element);
  }
}

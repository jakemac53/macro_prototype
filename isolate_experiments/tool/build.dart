import 'dart:async';
import 'dart:developer';
import 'dart:io' as io;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:graphs/graphs.dart';
import 'package:isolate_experiments/protocol.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'src/driver.dart';
import 'src/run_macro.dart';

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

  reflectType = (request) {
    var type = macroExecutor._resolveType(request.descriptor);
    var declaration = PackableClassDefinition.fromElement(
        type.element as ClassElement,
        originalReference: type);
    return ReflectTypeResponse(declaration);
  };
  getDeclaration = (request) {
    var declaration = macroExecutor.getDeclaration(request.descriptor);
    return GetDeclarationResponse(declaration);
  };

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
  final LibraryElement Function(Uri) resolveLibrary;
  final IsolateRef rootIsolate;
  final VmService vmService;
  static final runMacrosFile = io.File(p.join('tool', 'src', 'run_macro.dart'));
  static final runMacrosBackupFile =
      io.File(p.join('tool', 'src', 'run_macro.dart.backup'));

  _MacroExecutor({
    required this.resolveLibrary,
    required this.rootIsolate,
    required this.vmService,
  });

  static Future<_MacroExecutor> start(
      LibraryElement Function(Uri) resolveLibrary) async {
    _log('Connecting to vm service');
    var vmServiceInfo = await Service.getInfo();
    var vmService =
        await vmServiceConnectUri(vmServiceInfo.serverWebSocketUri!.toString());
    var vm = await vmService.getVM();
    var rootIsolate = vm.isolates!.first;
    _log('Vm service connected');

    await runMacrosFile.rename(runMacrosBackupFile.path);

    return _MacroExecutor(
        resolveLibrary: resolveLibrary,
        rootIsolate: rootIsolate,
        vmService: vmService);
  }

  Future<void> close() async {
    await vmService.dispose();
    await runMacrosBackupFile.rename(runMacrosFile.path);
  }

  Future<void> _applyMacros(List<ResolvedLibraryResult> libraryCycle,
      DartType macroType, Phase phase) async {
    var typeSystem = libraryCycle.first.element.typeSystem;
    for (var library in libraryCycle) {
      var finder = _MacroApplicationFinder(macroType, typeSystem)
        ..visitLibraryElement(library.element);
      for (var match in finder.matches) {
        var watch = Stopwatch();
        _log(
            'Sending macro request for ${match.annotation.toSource()} matching '
            'type ${macroType.getDisplayString(withNullability: false)} on '
            '${match.annotatedElement}');
        watch.start();
        var macroClass = match.value.type as InterfaceType;
        var appliedToClass = match.annotatedElement as ClassElement;
        var request = RunMacroRequest(
            _macroId(macroClass.element),
            const <String, Object?>{},
            DeclarationDescriptor(appliedToClass.source.uri.toString(), null,
                appliedToClass.name, DeclarationType.clazz),
            phase);
        var response = runMacro(request);
        _log(
            'Macro response: ${response.generatedCode} (took ${watch.elapsed})');
        watch
          ..stop()
          ..reset();
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

    await _writeRunMacrosFile(allMacros, runMacrosFile);
    var reloadResult =
        await vmService.callMethod('reloadSources', isolateId: rootIsolate.id);
    _log('Isolate reloaded: $reloadResult');
    return macros;
  }

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

  Packable getDeclaration(DeclarationDescriptor descriptor) {
    var library = resolveLibrary(Uri.parse(descriptor.libraryUri));
    var parentType = descriptor.parentType;
    Element element;
    if (parentType == null) {
      element = library.topLevelElements
          .firstWhere((element) => element.name == descriptor.name);
    } else {
      var parentTypeElement = library.getType(parentType)!;
      switch (descriptor.declarationType) {
        case DeclarationType.clazz:
          element = parentTypeElement;
          break;
        case DeclarationType.field:
          element = parentTypeElement.getField(descriptor.name)!;
          break;
        case DeclarationType.method:
          element = parentTypeElement.getMethod(descriptor.name)!;
          break;
        case DeclarationType.constructor:
          if (descriptor.name.isEmpty) {
            element = parentTypeElement.unnamedConstructor!;
          } else {
            element = parentTypeElement.getNamedConstructor(descriptor.name)!;
          }
          break;
      }
    }
    Packable declaration;
    switch (descriptor.declarationType) {
      case DeclarationType.clazz:
        declaration = PackableClassDefinition.fromElement(
            element as ClassElement,
            originalReference: element.thisType);
        break;
      case DeclarationType.field:
        declaration =
            PackableFieldDefinition.fromElement(element as FieldElement);
        break;
      case DeclarationType.method:
        declaration =
            PackableMethodDefinition.fromElement(element as MethodElement);
        break;
      case DeclarationType.constructor:
        declaration = PackableConstructorDefinition.fromElement(
            element as ConstructorElement);
        break;
    }
    return declaration;
  }
}

Stream<Uri> _findExampleLibraryUris() async* {
  await for (var entity in io.Directory('example').list(recursive: true)) {
    if (entity is! io.File) continue;
    yield entity.absolute.uri;
  }
}

const _macroImportsStart = '// START MACRO IMPORTS MARKER';
const _macroImportsEnd = '// END MACRO IMPORTS MARKER';
const _macroCaseStart = '// START MACRO CASE MARKER';
const _macroCaseEnd = '// END MACRO CASE MARKER';
Future<void> _writeRunMacrosFile(
    List<ClassElement> macros, io.File runMacrosFile) async {
  var importsAdded = <Uri>{};
  var content = await runMacrosFile.readAsString();
  var importsStartOffset =
      content.indexOf(_macroImportsStart) + _macroImportsStart.length + 1;
  var code = StringBuffer(content.substring(0, importsStartOffset));
  for (var macro in macros) {
    if (importsAdded.add(macro.librarySource.uri)) {
      code.writeln('import \'${macro.librarySource.uri}\';');
    }
  }
  var importsEndOffset = content.indexOf(_macroImportsEnd);
  var caseStartOffset =
      content.indexOf(_macroCaseStart) + _macroCaseStart.length + 1;

  code.write(content.substring(importsEndOffset, caseStartOffset));

  for (var macro in macros) {
    // TODO: support arguments to constructors
    code.writeln('''
    case '${_macroId(macro)}':
      macro = const ${macro.name}();
      break;''');
  }
  var caseEndOffset = content.indexOf(_macroCaseEnd);
  code.write(content.substring(caseEndOffset));
  await runMacrosFile.writeAsString(code.toString());
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

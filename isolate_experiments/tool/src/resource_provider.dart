import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/timestamped_data.dart';
import 'package:path/path.dart' as p;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:package_config/package_config.dart';
import 'package:watcher/src/watch_event.dart';

class CustomResourceProvider extends PhysicalResourceProvider {
  final PackageConfig packageConfig;

  CustomResourceProvider(this.packageConfig);

  @override
  File getFile(String path) {
    return _wrapResource(
        super.getFile(_resolvePath(path, packageConfig)), path, this);
  }

  @override
  Folder getFolder(String path) {
    return _wrapResource(
        super.getFolder(_resolvePath(path, packageConfig)), path, this);
  }

  @override
  Resource getResource(String path) {
    return _wrapResource(
        super.getResource(_resolvePath(path, packageConfig)), path, this);
  }
}

class WrappedFile implements File {
  final File _delegate;

  @override
  final String path;

  WrappedFile(this._delegate, this.path);

  @override
  Stream<WatchEvent> get changes => _delegate.changes;

  @override
  File copyTo(Folder parentFolder) => _delegate.copyTo(parentFolder);

  @override
  Source createSource([Uri? uri]) =>
      WrappedSource(_delegate.createSource(uri ?? toUri()), path);

  @override
  void delete() => _delegate.delete();

  @override
  bool get exists => _delegate.exists;

  @override
  bool isOrContains(String path) => _delegate.isOrContains(path);

  @override
  int get lengthSync => _delegate.lengthSync;

  @override
  int get modificationStamp => _delegate.modificationStamp;

  @override
  // ignore: deprecated_member_use
  Folder? get parent => _delegate.parent;

  @override
  Folder get parent2 => _delegate.parent2;

  @override
  ResourceProvider get provider => _delegate.provider;

  @override
  List<int> readAsBytesSync() => _delegate.readAsBytesSync();

  @override
  String readAsStringSync() => _delegate.readAsStringSync();

  @override
  File renameSync(String newPath) {
    throw UnimplementedError();
  }

  @override
  Resource resolveSymbolicLinksSync() {
    throw UnimplementedError();
  }

  @override
  String get shortName => _delegate.shortName;

  @override
  Uri toUri() => Uri(scheme: 'asset', path: path);

  @override
  void writeAsBytesSync(List<int> bytes) {
    throw UnimplementedError();
  }

  @override
  void writeAsStringSync(String content) {
    throw UnimplementedError();
  }
}

class WrappedFolder implements Folder {
  final Folder _delegate;

  final ResourceProvider _resourceProvider;

  @override
  final String path;

  WrappedFolder(this._delegate, this.path, this._resourceProvider);

  @override
  String canonicalizePath(String path) => p.canonicalize(path);

  @override
  Stream<WatchEvent> get changes => _delegate.changes;

  @override
  bool contains(String path) => p.isWithin(this.path, path);

  @override
  Folder copyTo(Folder parentFolder) {
    throw UnimplementedError();
  }

  @override
  void create() {
    throw UnimplementedError();
  }

  @override
  void delete() {
    throw UnimplementedError();
  }

  @override
  bool get exists => _delegate.exists;

  @override
  Resource getChild(String relPath) => _delegate.getChild(relPath);

  @override
  File getChildAssumingFile(String relPath) =>
      _delegate.getChildAssumingFile(relPath);

  @override
  Folder getChildAssumingFolder(String relPath) =>
      _delegate.getChildAssumingFolder(relPath);

  @override
  List<Resource> getChildren() => [
        for (var child in _delegate.getChildren()) _normalize(child),
      ];

  @override
  bool isOrContains(String path) => path == this.path || contains(path);

  @override
  bool get isRoot => _delegate.isRoot;

  @override
  Folder? get parent {
    // ignore: deprecated_member_use
    var p = _delegate.parent;
    if (p == null) return null;
    return _normalize(p);
  }

  @override
  Folder get parent2 => _normalize(_delegate.parent2);

  @override
  ResourceProvider get provider => _resourceProvider;

  @override
  Resource resolveSymbolicLinksSync() {
    throw UnimplementedError();
  }

  @override
  String get shortName => path;

  @override
  Uri toUri() => Uri(scheme: 'asset', path: path);

  T _normalize<T extends Resource>(T child) {
    var relative = p.relative(child.path, from: _delegate.path);
    return _wrapResource(child, p.join(path, relative), _resourceProvider);
  }
}

class WrappedSource implements Source {
  final Source _delegate;
  final String path;

  WrappedSource(this._delegate, this.path);

  @override
  TimestampedData<String> get contents => _delegate.contents;

  @override
  // ignore: deprecated_member_use
  String get encoding => _delegate.encoding;

  @override
  bool exists() => _delegate.exists();

  @override
  String get fullName => path;

  @override
  bool get isInSystemLibrary => _delegate.isInSystemLibrary;

  @override
  Source get librarySource => _delegate.librarySource;

  @override
  int get modificationStamp => _delegate.modificationStamp;

  @override
  String get shortName => _delegate.shortName;

  @override
  Source get source => _delegate.source;

  @override
  Uri get uri => Uri(scheme: 'asset', path: path);

  @override
  UriKind get uriKind => _delegate.uriKind;
}

String _resolvePath(String original, PackageConfig packageConfig) {
  var parts = p.url.split(original);
  var package =
      packageConfig.packages.firstWhere((pkg) => pkg.name == parts[1]);
  return p.url.joinAll([
    '/',
    ...package.root.pathSegments,
    ...parts.skip(2),
  ]);
}

T _wrapResource<T extends Resource>(
    T resource, String path, ResourceProvider resourceProvider) {
  if (resource is Folder) {
    return WrappedFolder(resource, path, resourceProvider) as T;
  } else if (resource is File) {
    return WrappedFile(resource, path) as T;
  } else {
    throw StateError('Unrecognized resource type $resource');
  }
}

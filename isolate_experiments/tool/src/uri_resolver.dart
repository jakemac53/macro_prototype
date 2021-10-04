import 'package:analyzer/file_system/file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/generated/source.dart';
import 'package:package_config/package_config.dart';

class CustomUriResolver extends UriResolver {
  final PackageConfig packageConfig;
  final ResourceProvider resourceProvider;

  CustomUriResolver(this.packageConfig, this.resourceProvider);

  /// Attempts to normalize [uri] into an `asset:` uri.
  ///
  /// Handles 'package:' or 'asset:' URIs.
  ///
  /// Returns `null` for `dart` or `dart-ext` uris.
  ///
  /// Throws a [StateError] if the Uri is not recognized.
  Uri? normalize(Uri uri) {
    switch (uri.scheme) {
      case 'package':
        var parts = uri.pathSegments;
        return Uri(scheme: 'asset', pathSegments: [
          parts.first,
          'lib',
          ...parts.skip(1),
        ]);
      case 'asset':
        return uri;
      case 'file':
        var pkg = packageConfig.packageOf(uri)!;
        return Uri(
            scheme: 'asset',
            path:
                '/${pkg.name}${uri.path.substring(pkg.root.path.length - 1)}');
      case 'dart':
      case 'dart-ext':
        return null;
      default:
        throw StateError('Unrecognized uri `$uri`.');
    }
  }

  @override
  Source? resolveAbsolute(Uri uri, [Uri? actualUri]) {
    final normalized = normalize(uri);
    if (normalized == null) return null;

    return resourceProvider.getFile(normalized.path).createSource(normalized);
  }

  @override
  Uri? restoreAbsolute(Source source) => normalize(source.uri);
}

import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Narrow file-system seam the content browser needs (§6a): list a directory,
/// read/write a file, test existence. Kept minimal (and separate from
/// `ForgeFileSystem`) so the content layer is unit-testable with an in-memory
/// fake; the module injects [ForgeContentFs] over the shell file system.
abstract class WebsiteContentFs {
  /// Lists the files directly under [directory] (non-recursive).
  Future<List<Uri>> listFiles(Uri directory);

  /// Reads [uri] as text.
  Future<String> read(Uri uri);

  /// Writes [content] to [uri].
  Future<void> write(Uri uri, String content);

  /// Whether [uri] exists.
  Future<bool> exists(Uri uri);
}

/// Adapts a [ForgeFileSystem] to the [WebsiteContentFs] seam.
class ForgeContentFs implements WebsiteContentFs {
  const ForgeContentFs(this._fs);

  final ForgeFileSystem _fs;

  @override
  Future<List<Uri>> listFiles(Uri directory) async {
    if (!await _fs.exists(directory)) return const [];
    final entities = await _fs.list(directory);
    return [for (final entity in entities) entity.uri];
  }

  @override
  Future<String> read(Uri uri) => _fs.read(uri);

  @override
  Future<void> write(Uri uri, String content) => _fs.write(uri, content);

  @override
  Future<bool> exists(Uri uri) => _fs.exists(uri);
}

/// A `dir/glob` pattern from the `content:` block (e.g. `components/*.yaml`),
/// split into the directory to list and a filename matcher.
class ContentGlob {
  ContentGlob(String pattern, {required Uri base})
      : _filenameGlob = _filenamePart(pattern),
        directory = base.resolve(_directoryPart(pattern));

  /// The directory to list for matches.
  final Uri directory;
  final String _filenameGlob;

  static String _directoryPart(String pattern) {
    final slash = pattern.lastIndexOf('/');
    return slash < 0 ? '' : pattern.substring(0, slash + 1);
  }

  static String _filenamePart(String pattern) {
    final slash = pattern.lastIndexOf('/');
    return slash < 0 ? pattern : pattern.substring(slash + 1);
  }

  /// Matches a file [uri]'s last path segment against the `*.ext` (or literal)
  /// filename glob. Only a single leading `*` wildcard is supported (the form
  /// the config uses); anything else is matched literally.
  bool matches(Uri uri) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (_filenameGlob.startsWith('*')) {
      return segment.endsWith(_filenameGlob.substring(1));
    }
    return segment == _filenameGlob;
  }
}

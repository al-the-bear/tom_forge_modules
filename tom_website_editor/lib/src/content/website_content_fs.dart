import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeRenameFileOperation, ForgeWorkspaceEdit, forgeApplyWorkspaceEdit;
import 'package:tom_file_system/tom_file_system.dart';

/// A directory entry with its file-vs-directory kind, returned by
/// [WebsiteContentFs.listEntries]. The structure explorer (§6b) needs the kind
/// to build a filesystem tree; the content browser (§6a) only needs file Uris.
class ContentFsEntry {
  const ContentFsEntry({required this.uri, required this.isDirectory});

  /// The entry's location.
  final Uri uri;

  /// Whether the entry is a directory (vs a file).
  final bool isDirectory;
}

/// Narrow file-system seam the content browser needs (§6a): list a directory,
/// read/write a file, test existence. Kept minimal (and separate from
/// `TomFileSystem`) so the content layer is unit-testable with an in-memory
/// fake; the module injects [ForgeContentFs] over the shell file system.
abstract class WebsiteContentFs {
  /// Lists the files directly under [directory] (non-recursive).
  Future<List<Uri>> listFiles(Uri directory);

  /// Lists the entries directly under [directory] (non-recursive), with each
  /// entry's file/directory kind. Used by the §6b structure explorer.
  Future<List<ContentFsEntry>> listEntries(Uri directory);

  /// Reads [uri] as text.
  Future<String> read(Uri uri);

  /// Writes [content] to [uri].
  Future<void> write(Uri uri, String content);

  /// Whether [uri] exists.
  Future<bool> exists(Uri uri);

  /// Deletes the file at [uri] (§9 tree affordance).
  Future<void> delete(Uri uri);

  /// Renames/moves the file from [from] to [to] (§9 tree affordance).
  Future<void> rename(Uri from, Uri to);
}

/// Adapts a [TomFileSystem] to the [WebsiteContentFs] seam.
class ForgeContentFs implements WebsiteContentFs {
  const ForgeContentFs(this._fs);

  final TomFileSystem _fs;

  @override
  Future<List<Uri>> listFiles(Uri directory) async {
    if (!await _fs.exists(directory)) return const [];
    final entities = await _fs.list(directory);
    return [for (final entity in entities) entity.uri];
  }

  @override
  Future<List<ContentFsEntry>> listEntries(Uri directory) async {
    if (!await _fs.exists(directory)) return const [];
    final entities = await _fs.list(directory);
    return [
      for (final entity in entities)
        ContentFsEntry(
          uri: entity.uri,
          isDirectory: entity.isDirectory,
        ),
    ];
  }

  @override
  Future<String> read(Uri uri) => _fs.readText(uri);

  @override
  Future<void> write(Uri uri, String content) =>
      _fs.writeText(uri, content);

  @override
  Future<bool> exists(Uri uri) => _fs.exists(uri);

  @override
  Future<void> delete(Uri uri) => _fs.delete(uri);

  @override
  Future<void> rename(Uri from, Uri to) async {
    // TomFileSystem has no direct rename; the atomic file-operation edit is
    // the supported path. A `false` return means the edit was rolled back.
    final ok = await forgeApplyWorkspaceEdit(_fs, ForgeWorkspaceEdit(
        fileOperations: [ForgeRenameFileOperation(oldUri: from, newUri: to)],
      ),
    );
    if (!ok) {
      throw StateError('Failed to rename $from to $to');
    }
  }
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

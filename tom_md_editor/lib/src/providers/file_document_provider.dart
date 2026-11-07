import 'package:tom_file_system/tom_file_system.dart';

import '../debug/md_editor_debug.dart';
import 'md_document_provider.dart';

/// Document provider that loads and saves a Markdown file through a
/// [TomFileSystem] — the host's files on disk, in memory or on the web.
///
/// ```dart
/// final provider = FileDocumentProvider(
///   fileSystem: shell.fileSystem,
///   uri: shell.fileSystem.uriOf('docs/readme.md'),
/// );
/// ```
class FileDocumentProvider implements MdDocumentProvider {
  FileDocumentProvider({required this.fileSystem, required this.uri});

  /// The file system the document is read and written through.
  final TomFileSystem fileSystem;

  /// The Markdown file.
  final Uri uri;

  @override
  MdDocumentMetadata get metadata => MdDocumentMetadata(
    path: uri.toFilePath(),
    title: uri.pathSegments.isEmpty ? '' : uri.pathSegments.last,
  );

  @override
  bool get canSave => true;

  @override
  Stream<String>? get externalChanges => null;

  /// The file's text; a file that does not exist (or cannot be read) is an
  /// empty document.
  @override
  Future<String> load() async {
    try {
      if (!await fileSystem.exists(uri)) return '';
      return await fileSystem.readText(uri);
    } on Exception catch (e, st) {
      MdEditorDebug.logger.error('Error loading file: $uri', e, st);
      return '';
    }
  }

  /// Writes [markdown] to the file, making its folder when it is missing.
  @override
  Future<void> save(String markdown) async {
    try {
      final segments = uri.pathSegments;
      if (segments.length > 1) {
        final folder = uri.replace(
          pathSegments: [...segments.sublist(0, segments.length - 1), ''],
        );
        if (!await fileSystem.exists(folder)) {
          await fileSystem.create(folder, directory: true);
        }
      }
      await fileSystem.writeText(uri, markdown);
    } on Exception catch (e, st) {
      MdEditorDebug.logger.error('Error saving file: $uri', e, st);
      rethrow;
    }
  }
}

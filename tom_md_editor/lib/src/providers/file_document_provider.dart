import 'dart:io';

import '../debug/md_editor_debug.dart';
import 'md_document_provider.dart';

/// Document provider that loads/saves markdown from a file path.
///
/// Supports file-system based documents with optional file watching.
/// ```dart
/// final provider = FileDocumentProvider(path: '/docs/readme.md');
/// ```
class FileDocumentProvider implements MdDocumentProvider {
  FileDocumentProvider({
    required this.path,
    this.watch = false,
  });

  /// Path to the markdown file.
  final String path;

  /// Whether to watch the file for external changes.
  final bool watch;

  @override
  MdDocumentMetadata get metadata => MdDocumentMetadata(
        path: path,
        title: path.split(Platform.pathSeparator).last,
      );

  @override
  bool get canSave => true;

  @override
  Stream<String>? get externalChanges => null;

  @override
  Future<String> load() async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return '';
      }
      return await file.readAsString();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error loading file: $path', e, st);
      return '';
    }
  }

  @override
  Future<void> save(String markdown) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(markdown);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error saving file: $path', e, st);
      rethrow;
    }
  }
}

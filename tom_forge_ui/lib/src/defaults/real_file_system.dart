import 'dart:async';
import 'dart:io';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Real file system implementation backed by dart:io.
///
/// Provides access to the actual file system on disk.
class RealFileSystem implements ForgeFileSystem {
  final Directory rootDirectory;
  final _changeController = StreamController<FileChangeEvent>.broadcast();
  final _saveController = StreamController<Uri>.broadcast();
  final _willSaveController = StreamController<WillSaveEvent>.broadcast();

  RealFileSystem({required this.rootDirectory});

  String _resolvePath(Uri uri) {
    // Handle file:// URIs
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }
    // Handle relative paths
    final path = uri.path;
    if (path.startsWith('/')) {
      return '${rootDirectory.path}$path';
    }
    return '${rootDirectory.path}/$path';
  }

  @override
  Future<String> read(Uri uri) async {
    final file = File(_resolvePath(uri));
    return file.readAsString();
  }

  @override
  Future<List<int>> readBytes(Uri uri) async {
    final file = File(_resolvePath(uri));
    return file.readAsBytes();
  }

  @override
  Future<void> write(Uri uri, String content) async {
    final file = File(_resolvePath(uri));
    await file.writeAsString(content);
    _changeController.add(FileChangeEvent(
      uri: uri,
      type: FileChangeType.modified,
    ));
  }

  @override
  Future<void> save(Uri uri) async {
    final content = await read(uri);
    _willSaveController.add(WillSaveEvent(
      uri: uri,
      content: content,
      reason: SaveReason.manual,
    ));
    _saveController.add(uri);
  }

  @override
  Future<void> delete(Uri uri) async {
    final path = _resolvePath(uri);
    final file = File(path);
    final dir = Directory(path);

    if (await file.exists()) {
      await file.delete();
    } else if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    _changeController.add(FileChangeEvent(
      uri: uri,
      type: FileChangeType.deleted,
    ));
  }

  @override
  Future<bool> exists(Uri uri) async {
    final path = _resolvePath(uri);
    final fileExists = await File(path).exists();
    final dirExists = await Directory(path).exists();
    return fileExists || dirExists;
  }

  @override
  Future<FileStat> stat(Uri uri) async {
    final path = _resolvePath(uri);
    return FileStat.stat(path);
  }

  @override
  Future<List<FileSystemEntity>> list(
    Uri directoryUri, {
    bool recursive = false,
  }) async {
    final path = _resolvePath(directoryUri);
    final dir = Directory(path);

    if (!await dir.exists()) {
      return [];
    }

    final entities = <FileSystemEntity>[];
    final stream = dir.list(
      recursive: recursive,
      followLinks: false,
    ).handleError((Object error) {
      // Ignore inaccessible sub-paths so explorer can still render
      // all readable files in the workspace tree.
    }, test: (error) => error is FileSystemException);

    await for (final entity in stream) {
      // Skip hidden files and .git directories
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;

      entities.add(entity);
    }

    // Sort: directories first, then alphabetically
    entities.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
      return a.path.compareTo(b.path);
    });

    return entities;
  }

  @override
  Stream<FileSystemEvent> watch(Uri uri, {bool recursive = false}) {
    final path = _resolvePath(uri);
    final dir = Directory(path);
    final file = File(path);

    if (dir.existsSync()) {
      return dir.watch(recursive: recursive);
    } else if (file.existsSync()) {
      return file.watch();
    }

    return const Stream.empty();
  }

  @override
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit) async {
    try {
      for (final entry in edit.textEdits.entries) {
        final uri = entry.key;
        final edits = entry.value;

        // Read current content
        final content = await read(uri);
        var newContent = content;

        // Apply edits in reverse order to preserve offsets
        final sortedEdits = List.of(edits)
          ..sort((a, b) => b.range.start.line.compareTo(a.range.start.line));

        for (final textEdit in sortedEdits) {
          final lines = newContent.split('\n');
          final startLine = textEdit.range.start.line;
          final endLine = textEdit.range.end.line;
          final startCol = textEdit.range.start.column;
          final endCol = textEdit.range.end.column;

          if (startLine == endLine) {
            // Single line edit
            final line = lines[startLine];
            final newLine = line.substring(0, startCol) +
                textEdit.newText +
                line.substring(endCol);
            lines[startLine] = newLine;
          } else {
            // Multi-line edit
            final startSegment = lines[startLine].substring(0, startCol);
            final endSegment = lines[endLine].substring(endCol);
            final newLines = textEdit.newText.split('\n');

            lines.removeRange(startLine, endLine + 1);
            if (newLines.length == 1) {
              lines.insert(startLine, startSegment + newLines[0] + endSegment);
            } else {
              newLines[0] = startSegment + newLines[0];
              newLines[newLines.length - 1] =
                  newLines[newLines.length - 1] + endSegment;
              lines.insertAll(startLine, newLines);
            }
          }

          newContent = lines.join('\n');
        }

        await write(uri, newContent);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<FileChangeEvent> get onDidChange => _changeController.stream;

  @override
  Stream<Uri> get onDidSave => _saveController.stream;

  @override
  Stream<WillSaveEvent> get onWillSave => _willSaveController.stream;

  void dispose() {
    _changeController.close();
    _saveController.close();
    _willSaveController.close();
  }
}

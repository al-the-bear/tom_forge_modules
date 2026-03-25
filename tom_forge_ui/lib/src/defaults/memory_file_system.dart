import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, FileStat, FileSystemEntity, FileSystemEntityType, FileSystemEvent;

import 'package:tom_forge_core/tom_forge_core.dart';

/// In-memory [FileStat] shim for [MemoryFileSystem].
class MemoryFileStat implements FileStat {
  final int _size;
  final bool _isDirectory;
  final DateTime _modified;

  MemoryFileStat({
    int size = 0,
    bool isDirectory = false,
    DateTime? modified,
  })  : _size = size,
        _isDirectory = isDirectory,
        _modified = modified ?? DateTime.now();

  @override
  DateTime get changed => _modified;

  @override
  DateTime get modified => _modified;

  @override
  DateTime get accessed => _modified;

  @override
  int get size => _size;

  @override
  int get mode => 0;

  @override
  FileSystemEntityType get type =>
      _isDirectory ? FileSystemEntityType.directory : FileSystemEntityType.file;

  @override
  String modeString() => 'rwxrwxrwx';
}

/// In-memory [FileSystemEntity] shim for [MemoryFileSystem].
class MemoryFileEntry implements FileSystemEntity {
  @override
  final String path;

  @override
  final Uri uri;

  final bool isDirectory;

  MemoryFileEntry({
    required this.path,
    this.isDirectory = false,
  }) : uri = Uri.parse('file://$path');

  @override
  FileSystemEntity get absolute => this;

  @override
  Future<bool> exists() async => true;

  @override
  bool existsSync() => true;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;

  @override
  void deleteSync({bool recursive = false}) {}

  @override
  Future<FileSystemEntity> rename(String newPath) async =>
      MemoryFileEntry(path: newPath, isDirectory: isDirectory);

  @override
  FileSystemEntity renameSync(String newPath) =>
      MemoryFileEntry(path: newPath, isDirectory: isDirectory);

  @override
  Directory get parent {
    final parentPath = path.contains('/')
        ? path.substring(0, path.lastIndexOf('/'))
        : '/';
    return Directory(parentPath.isEmpty ? '/' : parentPath);
  }

  @override
  bool get isAbsolute => path.startsWith('/');

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) =>
      const Stream.empty();

  @override
  Future<FileStat> stat() async =>
      MemoryFileStat(isDirectory: isDirectory);

  @override
  FileStat statSync() => MemoryFileStat(isDirectory: isDirectory);

  @override
  Future<String> resolveSymbolicLinks() async => path;

  @override
  String resolveSymbolicLinksSync() => path;
}

/// In-memory implementation of [ForgeFileSystem].
///
/// Backed by [Map<String, List<int>>]. Fires change/save streams
/// on mutations.
class MemoryFileSystem implements ForgeFileSystem {
  static bool debugEnabled = false;

  final Map<String, List<int>> _files = {};

  final _changeController =
      StreamController<FileChangeEvent>.broadcast();
  final _saveController = StreamController<Uri>.broadcast();
  final _willSaveController =
      StreamController<WillSaveEvent>.broadcast();

  /// Creates a [MemoryFileSystem] seeded with text files.
  MemoryFileSystem({Map<String, String> seed = const {}}) {
    for (final entry in seed.entries) {
      _files[entry.key] = utf8.encode(entry.value);
    }
  }

  @override
  Future<String> read(Uri uri) async {
    final key = uri.path;
    final bytes = _files[key];
    if (bytes == null) {
      throw FileSystemException('File not found: $key');
    }
    return utf8.decode(bytes);
  }

  @override
  Future<List<int>> readBytes(Uri uri) async {
    final key = uri.path;
    final bytes = _files[key];
    if (bytes == null) {
      throw FileSystemException('File not found: $key');
    }
    return List.unmodifiable(bytes);
  }

  @override
  Future<void> write(Uri uri, String content) async {
    final key = uri.path;
    final isNew = !_files.containsKey(key);
    _files[key] = utf8.encode(content);
    _changeController.add(FileChangeEvent(
      uri: uri,
      type: isNew ? FileChangeType.created : FileChangeType.modified,
    ));
    if (debugEnabled) {
      // ignore: avoid_print
      print('[MemoryFileSystem] write: $key (${content.length} chars)');
    }
  }

  @override
  Future<void> save(Uri uri) async {
    final key = uri.path;
    if (!_files.containsKey(key)) return;
    final content = utf8.decode(_files[key]!);
    final event =
        WillSaveEvent(uri: uri, content: content, reason: SaveReason.manual);
    _willSaveController.add(event);
    _files[key] = utf8.encode(event.content);
    _saveController.add(uri);
  }

  @override
  Future<void> delete(Uri uri) async {
    _files.remove(uri.path);
    _changeController.add(FileChangeEvent(
      uri: uri,
      type: FileChangeType.deleted,
    ));
  }

  @override
  Future<bool> exists(Uri uri) async => _files.containsKey(uri.path);

  @override
  Future<FileStat> stat(Uri uri) async {
    final bytes = _files[uri.path];
    if (bytes == null) return MemoryFileStat(size: 0);
    return MemoryFileStat(size: bytes.length);
  }

  @override
  Future<List<FileSystemEntity>> list(Uri directoryUri,
      {bool recursive = false}) async {
    final prefix = directoryUri.path.endsWith('/')
        ? directoryUri.path
        : '${directoryUri.path}/';

    final entries = <String>{};
    final dirs = <String>{};

    for (final key in _files.keys) {
      if (!key.startsWith(prefix)) continue;
      final relative = key.substring(prefix.length);
      if (recursive) {
        entries.add(key);
        final parts = relative.split('/');
        for (var i = 1; i < parts.length; i++) {
          dirs.add('$prefix${parts.sublist(0, i).join('/')}');
        }
      } else {
        final slashIndex = relative.indexOf('/');
        if (slashIndex == -1) {
          entries.add(key);
        } else {
          dirs.add('$prefix${relative.substring(0, slashIndex)}');
        }
      }
    }

    final result = <FileSystemEntity>[];
    for (final d in dirs) {
      result.add(MemoryFileEntry(path: d, isDirectory: true));
    }
    for (final f in entries) {
      result.add(MemoryFileEntry(path: f, isDirectory: false));
    }
    return result;
  }

  @override
  Stream<FileSystemEvent> watch(Uri uri, {bool recursive = false}) =>
      const Stream.empty();

  @override
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit) async {
    try {
      for (final entry in edit.textEdits.entries) {
        final uri = entry.key;
        final edits = entry.value;
        final key = uri.path;
        if (!_files.containsKey(key)) continue;
        var content = utf8.decode(_files[key]!);
        final sorted = List.of(edits)
          ..sort((a, b) {
            final lineCmp = b.range.start.line.compareTo(a.range.start.line);
            if (lineCmp != 0) return lineCmp;
            return b.range.start.column.compareTo(a.range.start.column);
          });
        for (final textEdit in sorted) {
          final lines = content.split('\n');
          final startLine = textEdit.range.start.line;
          final startCol = textEdit.range.start.column;
          final endLine = textEdit.range.end.line;
          final endCol = textEdit.range.end.column;
          if (startLine >= lines.length) continue;
          final before = lines[startLine].substring(
              0, startCol.clamp(0, lines[startLine].length));
          final after = endLine < lines.length
              ? lines[endLine]
                  .substring(endCol.clamp(0, lines[endLine].length))
              : '';
          final newLines = textEdit.newText.split('\n');
          newLines[0] = before + newLines[0];
          newLines[newLines.length - 1] = newLines.last + after;
          lines.replaceRange(
              startLine, (endLine + 1).clamp(0, lines.length), newLines);
          content = lines.join('\n');
        }
        _files[key] = utf8.encode(content);
        _changeController.add(FileChangeEvent(
          uri: uri,
          type: FileChangeType.modified,
        ));
      }
      return true;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[MemoryFileSystem] applyWorkspaceEdit error: $e');
      }
      return false;
    }
  }

  @override
  Stream<FileChangeEvent> get onDidChange => _changeController.stream;

  @override
  Stream<Uri> get onDidSave => _saveController.stream;

  @override
  Stream<WillSaveEvent> get onWillSave => _willSaveController.stream;

  /// All stored file paths.
  Iterable<String> get paths => _files.keys;

  /// Dispose stream controllers.
  void dispose() {
    _changeController.close();
    _saveController.close();
    _willSaveController.close();
  }
}

/// Exception for file system operations.
class FileSystemException implements Exception {
  final String message;
  FileSystemException(this.message);

  @override
  String toString() => 'FileSystemException: $message';
}

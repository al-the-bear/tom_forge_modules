import 'dart:async';
import 'dart:io';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Real file system implementation backed by dart:io.
///
/// Provides access to the actual file system on disk.
/// Includes:
/// - **Watcher consolidation**: When the number of active watch paths
///   exceeds [maxWatcherPaths], individual watchers are consolidated
///   into recursive parent-directory watchers.
/// - **Event batching**: File-system events are batched within a
///   configurable window (default 50ms) to avoid UI thrashing.
/// - **Concurrent-access control**: Limits the number of parallel
///   file-system operations via a simple semaphore.
class RealFileSystem implements ForgeFileSystem {
  final Directory rootDirectory;
  final _changeController = StreamController<FileChangeEvent>.broadcast();
  final _saveController = StreamController<Uri>.broadcast();
  final _willSaveController = StreamController<WillSaveEvent>.broadcast();

  /// Maximum individual watcher paths before consolidation.
  final int maxWatcherPaths;

  /// Batching window for file-system events.
  final Duration watcherBatchWindow;

  /// Maximum concurrent file-system operations.
  final int maxConcurrentFileOps;

  /// Active individual watcher subscriptions, keyed by URI string.
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};

  /// Consolidated parent-directory watcher (active when threshold exceeded).
  StreamSubscription<FileSystemEvent>? _consolidatedWatcher;

  /// Event batcher for file-system watch events.
  late final EventBatcher<FileSystemEvent> _eventBatcher;

  /// Whether watcher consolidation is currently active.
  bool _isConsolidated = false;

  /// Simple semaphore for concurrent file-system operations.
  int _activeOps = 0;
  final List<Completer<void>> _opsQueue = [];

  RealFileSystem({
    required this.rootDirectory,
    this.maxWatcherPaths = 1000,
    this.watcherBatchWindow = const Duration(milliseconds: 50),
    this.maxConcurrentFileOps = 10,
  }) {
    _eventBatcher = EventBatcher<FileSystemEvent>(
      window: watcherBatchWindow,
    );
  }

  /// Acquire a concurrency slot. Waits if at capacity.
  Future<void> _acquireSlot() async {
    if (_activeOps < maxConcurrentFileOps) {
      _activeOps++;
      return;
    }
    final completer = Completer<void>();
    _opsQueue.add(completer);
    await completer.future;
    _activeOps++;
  }

  /// Release a concurrency slot, unblocking queued operations.
  void _releaseSlot() {
    _activeOps--;
    if (_opsQueue.isNotEmpty) {
      _opsQueue.removeAt(0).complete();
    }
  }

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
    await _acquireSlot();
    try {
      final file = File(_resolvePath(uri));
      return await file.readAsString();
    } finally {
      _releaseSlot();
    }
  }

  @override
  Future<List<int>> readBytes(Uri uri) async {
    await _acquireSlot();
    try {
      final file = File(_resolvePath(uri));
      return await file.readAsBytes();
    } finally {
      _releaseSlot();
    }
  }

  @override
  Future<void> write(Uri uri, String content) async {
    await _acquireSlot();
    try {
      final file = File(_resolvePath(uri));
      await file.writeAsString(content);
      _changeController.add(FileChangeEvent(
        uri: uri,
        type: FileChangeType.modified,
      ));
    } finally {
      _releaseSlot();
    }
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

    // If already consolidated, filter from the root watcher.
    if (_isConsolidated) {
      return _eventBatcher.batched
          .expand((batch) => batch)
          .where((event) => event.path.startsWith(path));
    }

    Stream<FileSystemEvent> raw;
    if (dir.existsSync()) {
      raw = dir.watch(recursive: recursive);
    } else if (file.existsSync()) {
      raw = file.watch();
    } else {
      return const Stream.empty();
    }

    // Track this watcher.
    final key = uri.toString();
    final controller = StreamController<FileSystemEvent>.broadcast(
      onCancel: () {
        _watchers.remove(key)?.cancel();
        // De-consolidate if we drop below threshold.
        if (_isConsolidated &&
            _watchers.length < maxWatcherPaths) {
          _deconsolidate();
        }
      },
    );

    final sub = raw.listen(
      (event) {
        _eventBatcher.add(event);
        controller.add(event);
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    _watchers[key] = sub;

    // Consolidate if threshold exceeded.
    if (_watchers.length > maxWatcherPaths && !_isConsolidated) {
      _consolidate();
    }

    return controller.stream;
  }

  /// Consolidate all individual watchers into a single recursive
  /// root-directory watcher.
  void _consolidate() {
    _isConsolidated = true;
    // Cancel all individual subscriptions.
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();
    // Start a single recursive watcher on the root.
    _consolidatedWatcher = rootDirectory
        .watch(recursive: true)
        .listen((event) => _eventBatcher.add(event));
  }

  /// Switch back to per-path watchers when the watcher count drops
  /// below threshold.
  void _deconsolidate() {
    _isConsolidated = false;
    _consolidatedWatcher?.cancel();
    _consolidatedWatcher = null;
  }

  @override
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit) async {
    // Atomic implementation: backup → apply → rollback on failure.
    final backups = <Uri, String>{};
    final createdFiles = <Uri>[];
    final deletedBackups = <Uri, String>{};
    final renamedFiles = <(Uri, Uri)>[];

    try {
      // Phase 1: Backup existing files that will be text-edited.
      for (final uri in edit.textEdits.keys) {
        if (await exists(uri)) {
          backups[uri] = await read(uri);
        }
      }

      // Phase 2: Apply file operations (create, delete, rename).
      for (final op in edit.fileOperations) {
        switch (op) {
          case ForgeCreateFileOperation(:final uri, :final content, :final overwrite):
            if (await exists(uri) && !overwrite) {
              throw StateError('File already exists: ${uri.toFilePath()}');
            }
            await write(uri, content ?? '');
            createdFiles.add(uri);
          case ForgeDeleteFileOperation(:final uri, :final recursive):
            if (await exists(uri)) {
              deletedBackups[uri] = await read(uri);
              final file = File(uri.toFilePath());
              await file.delete(recursive: recursive);
              _changeController.add(FileChangeEvent(
                uri: uri,
                type: FileChangeType.deleted,
              ));
            }
          case ForgeRenameFileOperation(:final oldUri, :final newUri, :final overwrite):
            if (!await exists(oldUri)) {
              throw StateError('Source file not found: ${oldUri.toFilePath()}');
            }
            if (await exists(newUri) && !overwrite) {
              throw StateError('Target file already exists: ${newUri.toFilePath()}');
            }

            final oldPath = oldUri.toFilePath();
            final newPath = newUri.toFilePath();
            final oldFile = File(oldPath);
            final oldDir = Directory(oldPath);
            final targetFile = File(newPath);
            final targetDir = Directory(newPath);

            if (overwrite) {
              if (await targetFile.exists()) {
                await targetFile.delete();
              } else if (await targetDir.exists()) {
                await targetDir.delete(recursive: true);
              }
            }

            if (await oldFile.exists()) {
              await oldFile.rename(newPath);
            } else if (await oldDir.exists()) {
              await oldDir.rename(newPath);
            } else {
              throw StateError('Source path not found: $oldPath');
            }

            renamedFiles.add((oldUri, newUri));
            _changeController.add(FileChangeEvent(
              uri: newUri,
              type: FileChangeType.created,
            ));
        }
      }

      // Phase 3: Apply text edits.
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
      // Rollback: restore backups, remove created files, restore deleted files.
      for (final entry in backups.entries) {
        try {
          await write(entry.key, entry.value);
        } catch (_) {
          // Best effort rollback.
        }
      }
      for (final uri in createdFiles) {
        try {
          final file = File(uri.toFilePath());
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Best effort rollback.
        }
      }
      for (final entry in deletedBackups.entries) {
        try {
          await write(entry.key, entry.value);
        } catch (_) {
          // Best effort rollback.
        }
      }
      for (final (oldUri, newUri) in renamedFiles) {
        try {
          final file = File(newUri.toFilePath());
          if (await file.exists()) {
            await file.rename(oldUri.toFilePath());
          }
        } catch (_) {
          // Best effort rollback.
        }
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

  void dispose() {
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();
    _consolidatedWatcher?.cancel();
    _eventBatcher.dispose();
    _changeController.close();
    _saveController.close();
    _willSaveController.close();
  }
}

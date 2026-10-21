/// What every [ForgeFileSystem] does the same way, written once: resolving
/// URIs against the root, text over bytes, the save announcements and the
/// all-or-nothing workspace edit.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../types/forge_enums.dart';
import '../types/forge_events.dart';
import '../types/workspace_edit.dart';
import 'file_system.dart';

/// A [ForgeFileSystem] whose implementation supplies the primitives — list,
/// stat, read, write, create, rename, trash, delete, watch — and announces
/// its own changes with [emitChange].
abstract class ForgeFileSystemBase implements ForgeFileSystem {
  /// [root] must be an absolute directory URI.
  ForgeFileSystemBase(Uri root)
    : root = root.path.endsWith('/') ? root : root.replace(path: '${root.path}/');

  @override
  final Uri root;

  final _changes = StreamController<FileChangeEvent>.broadcast();
  final _saves = StreamController<Uri>.broadcast();
  final _willSaves = StreamController<WillSaveEvent>.broadcast();

  /// [uri] made absolute against [root].
  Uri absolute(Uri uri) => uri.hasScheme ? uri : root.resolveUri(uri);

  @override
  Uri uriOf(String path) =>
      path.isEmpty ? root : root.resolveUri(Uri(path: path));

  @override
  String? pathOf(Uri uri) {
    final target = absolute(uri);
    if (target.scheme != root.scheme || target.authority != root.authority) {
      return null;
    }
    final base = [
      for (final s in root.pathSegments)
        if (s.isNotEmpty) s,
    ];
    final segments = [
      for (final s in target.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.length < base.length) return null;
    for (var i = 0; i < base.length; i++) {
      if (segments[i] != base[i]) return null;
    }
    return segments.skip(base.length).join('/');
  }

  /// The last segment of [uri]'s path — a file's or folder's own name.
  String nameOf(Uri uri) {
    final segments = absolute(uri).pathSegments.where((s) => s.isNotEmpty);
    return segments.isEmpty ? '' : segments.last;
  }

  /// Announces a change made through this file system.
  void emitChange(Uri uri, FileChangeType type) {
    if (!_changes.isClosed) {
      _changes.add(FileChangeEvent(uri: absolute(uri), type: type));
    }
  }

  @override
  Future<String> readText(Uri uri) async =>
      utf8.decode((await read(uri)).bytes, allowMalformed: true);

  @override
  Future<ForgeFileRevision> writeText(
    Uri uri,
    String text, {
    ForgeFileRevision? expected,
  }) => write(uri, Uint8List.fromList(utf8.encode(text)), expected: expected);

  @override
  Future<void> save(Uri uri) async {
    final content = await readText(uri);
    final event = WillSaveEvent(
      uri: absolute(uri),
      content: content,
      reason: SaveReason.manual,
    );
    _willSaves.add(event);
    // A listener may change what is saved.
    if (event.content != content) await writeText(uri, event.content);
    _saves.add(absolute(uri));
  }

  @override
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit) async {
    final backups = <Uri, Uint8List>{};
    final created = <Uri>[];
    final deleted = <Uri, Uint8List>{};
    final renamed = <(Uri, Uri)>[];
    try {
      for (final uri in edit.textEdits.keys) {
        if (await exists(uri)) backups[uri] = (await read(uri)).bytes;
      }
      for (final op in edit.fileOperations) {
        switch (op) {
          case ForgeCreateFileOperation(
            :final uri,
            :final content,
            :final overwrite,
          ):
            if (await exists(uri) && !overwrite) {
              throw StateError('File already exists: ${uri.path}');
            }
            await writeText(uri, content ?? '');
            created.add(uri);
          case ForgeDeleteFileOperation(:final uri):
            final entry = await stat(uri);
            if (entry != null) {
              if (!entry.isDirectory) deleted[uri] = (await read(uri)).bytes;
              await delete(uri);
            }
          case ForgeRenameFileOperation(
            :final oldUri,
            :final newUri,
            :final overwrite,
          ):
            if (!await exists(oldUri)) {
              throw StateError('Source file not found: ${oldUri.path}');
            }
            if (await exists(newUri)) {
              if (!overwrite) {
                throw StateError('Target file already exists: ${newUri.path}');
              }
              await delete(newUri);
            }
            await rename(oldUri, newUri);
            renamed.add((oldUri, newUri));
        }
      }
      // A text edit names a file that exists; one that does not is skipped.
      for (final entry in edit.textEdits.entries) {
        if (!await exists(entry.key)) continue;
        final text = await readText(entry.key);
        await writeText(entry.key, _applyTextEdits(text, entry.value));
      }
      return true;
    } on Object {
      // Undo in reverse: renames back, created files removed, deleted and
      // edited files restored. Best effort — a failure here leaves what is
      // left, and the edit still reports that it was not applied.
      for (final (from, to) in renamed.reversed) {
        await _quietly(() => rename(to, from));
      }
      for (final uri in created) {
        await _quietly(() => delete(uri));
      }
      for (final entry in {...deleted, ...backups}.entries) {
        await _quietly(() => write(entry.key, entry.value));
      }
      return false;
    }
  }

  static Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } on Object {
      // Rollback is best effort.
    }
  }

  /// [edits] applied to [text], the last position first so earlier offsets
  /// stay valid.
  static String _applyTextEdits(String text, List<ForgeTextEdit> edits) {
    final lines = text.split('\n');
    final sorted = List.of(edits)
      ..sort((a, b) {
        final byLine = b.range.start.line.compareTo(a.range.start.line);
        return byLine != 0
            ? byLine
            : b.range.start.column.compareTo(a.range.start.column);
      });
    for (final edit in sorted) {
      final start = edit.range.start;
      final end = edit.range.end;
      final head = lines[start.line].substring(0, start.column);
      final tail = lines[end.line].substring(end.column);
      final inserted = '$head${edit.newText}$tail'.split('\n');
      lines.replaceRange(start.line, end.line + 1, inserted);
    }
    return lines.join('\n');
  }

  @override
  Stream<FileChangeEvent> get onDidChange => _changes.stream;

  @override
  Stream<Uri> get onDidSave => _saves.stream;

  @override
  Stream<WillSaveEvent> get onWillSave => _willSaves.stream;

  @override
  Future<void> dispose() async {
    await _changes.close();
    await _saves.close();
    await _willSaves.close();
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_file_system/tom_file_system.dart';

import 'forge_state_store.dart';

/// A [ForgeStateStore] of files under [folder] of a [TomFileSystem] — the
/// default store of the workspace state, `.forge/` of the workspace: a key
/// is the file's path under [folder] (`state/editors/<hash>.json`).
///
/// - A key ending in `.json` holds a JSON document, written as
///   `JsonEncoder.withIndent('  ')` writes it and decoded on [read]; a file
///   that does not decode reads as null.
/// - Any other key holds text (a revision snapshot): its document must be a
///   String, written and read as it is.
///
/// Each write is atomic as every [TomFileSystem] write is (a temporary file
/// renamed into place); the folders of a key are created as needed, and
/// null deletes the file. Writes and deletes of one file run one after
/// another in the order they were started — per file system, so two stores
/// over one workspace keep the order too — and a [read] of the file waits
/// for them: two atomic writes in flight at once would otherwise leave
/// whichever *finished* last.
class ForgeFileStateStore implements ForgeStateStore {
  /// The store of [folder] (ending in `/`, relative to the root of
  /// [fileSystem]).
  ForgeFileStateStore(this.fileSystem, {String folder = '.forge/'})
    : folder = folder.isEmpty || folder.endsWith('/') ? folder : '$folder/';

  /// The file system the files are in.
  final TomFileSystem fileSystem;

  /// The folder the keys are relative to, ending in `/` (or empty: the
  /// root).
  final String folder;

  static bool debugEnabled = false;

  static void _log(String message) {
    if (debugEnabled) debugPrint('[ForgeFileStateStore] $message');
  }

  /// The URI of the file of [key].
  Uri uriOf(String key) => fileSystem.uriOf('$folder$key');

  /// Makes the folder [relative] under [folder] (and its parents) unless it
  /// exists.
  Future<void> ensureFolder(String relative) async {
    final path = relative.isEmpty || relative.endsWith('/')
        ? relative
        : '$relative/';
    final uri = fileSystem.uriOf('$folder$path');
    if (!await fileSystem.exists(uri)) {
      await fileSystem.create(uri, directory: true);
    }
  }

  /// The text a document of [key] is stored as.
  static String encode(String key, Object document) {
    if (key.endsWith('.json')) {
      return const JsonEncoder.withIndent('  ').convert(document);
    }
    if (document is String) return document;
    throw ArgumentError.value(
      document,
      'document',
      'the document of "$key" (not a .json key) must be a String',
    );
  }

  @override
  Future<Object?> read(String key) async {
    final uri = uriOf(key);
    final pending = _pendingOf(fileSystem)[uri];
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // A failed write leaves the file as it was: read that.
      }
    }
    final String text;
    try {
      if (!await fileSystem.exists(uri)) return null;
      text = await fileSystem.readText(uri);
    } on Exception catch (e) {
      _log('read $key failed: $e');
      return null;
    }
    if (!key.endsWith('.json')) return text;
    try {
      return jsonDecode(text);
    } on FormatException catch (e) {
      _log('decode $key failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? document) {
    final uri = uriOf(key);
    if (document == null) {
      return _inOrder(fileSystem, uri, () async {
        if (await fileSystem.exists(uri)) await fileSystem.delete(uri);
      });
    }
    final String text;
    try {
      text = encode(key, document);
    } on Object catch (error, stackTrace) {
      return Future.error(error, stackTrace);
    }
    return _inOrder(fileSystem, uri, () async {
      final slash = key.lastIndexOf('/');
      if (slash > 0) await ensureFolder(key.substring(0, slash));
      await fileSystem.writeText(uri, text);
    });
  }

  @override
  Future<List<String>> keys({String prefix = ''}) async {
    final found = <String>[];
    Future<void> walk(String relative) async {
      final uri = fileSystem.uriOf('$folder$relative');
      if (!await fileSystem.exists(uri)) return;
      for (final entry in await fileSystem.list(uri)) {
        final key = '$relative${entry.name}';
        if (entry.kind == TomFileEntryKind.directory) {
          await walk('$key/');
        } else if (entry.kind == TomFileEntryKind.file) {
          if (key.startsWith(prefix)) found.add(key);
        }
      }
    }

    await walk('');
    return found..sort();
  }

  @override
  Future<void> flushed() async {
    final pending = _pendingOf(fileSystem);
    while (pending.isNotEmpty) {
      await Future.wait([
        for (final write in pending.values.toList())
          write.catchError((Object _) {}),
      ]);
    }
  }

  /// The last write or delete started on each file of a file system, by its
  /// URI, until it has ended — per file-system instance, so two workspaces
  /// (or two tests) never wait for each other.
  static final Expando<Map<Uri, Future<void>>> _pendingByFs = Expando();

  static Map<Uri, Future<void>> _pendingOf(TomFileSystem fs) =>
      _pendingByFs[fs] ??= {};

  /// Runs [operation] on [uri] after the write or delete started on it
  /// before has ended, whether that succeeded or not.
  static Future<void> _inOrder(
    TomFileSystem fs,
    Uri uri,
    Future<void> Function() operation,
  ) {
    final pending = _pendingOf(fs);
    final previous = pending[uri];
    final next = previous == null
        ? operation()
        : previous.then((_) => operation(), onError: (Object _) => operation());
    pending[uri] = next;
    void ended() {
      if (identical(pending[uri], next)) pending.remove(uri);
    }

    next.then((_) => ended(), onError: (Object _) => ended());
    return next;
  }
}

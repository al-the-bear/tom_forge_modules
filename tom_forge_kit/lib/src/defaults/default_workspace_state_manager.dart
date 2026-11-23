import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_file_system/tom_file_system.dart';

import '../kit/forge_coalesced_state_writer.dart';
import '../kit/forge_file_state_store.dart';
import '../kit/forge_state_store.dart';
import '../services/forge_workspace_state_manager.dart';

/// Default implementation of [ForgeWorkspaceStateManager]: its keyed
/// documents go through a [ForgeStateStore].
///
/// Without a store given, the store is a [ForgeFileStateStore] over the
/// `.forge/` directory of the workspace given to [initialize], with the
/// following structure (the keys are the paths under `.forge/`):
/// ```
/// .forge/
///   config.json
///   state/
///     applications.json
///     apps/
///       {app-id-hash}.json
///     editors/
///       {uri-hash}.json
///   revisions/
///     {uri-hash}/
///       {timestamp}.snapshot
///       manifest.json
///   undo/
///     {uri-hash}.json
/// ```
/// The `.json` files are JSON indented by two spaces, a `.snapshot` the
/// revision's text as it is. With a store given (a host that persists
/// elsewhere, a test), the same keys are written to it and the workspace's
/// file system is not touched by the state.
///
/// A state document that cannot be read or is of another shape counts as
/// absent (no migrations: the state is per machine).
///
/// **Once per gesture, never before the restore.** Every write goes
/// through a [ForgeCoalescedStateWriter]: two writes of one document within
/// a microtask (the shell's debounced layout save and the one at exit, say)
/// store the last one once, and a read of a document waits for the writes of
/// it started before. Nothing can be written before [initialize] has
/// finished — every operation refuses then, as [isInitialized] is false.
///
/// Every operation takes the store once, before its first await, and works
/// with it to the end: the shell writes state at exit and disposes this
/// manager in the same frame, so a write in flight must not look the store
/// up again; [flushed] waits for the writes of the last [initialize] even
/// after [dispose].
class DefaultWorkspaceStateManager implements ForgeWorkspaceStateManager {
  /// A manager whose documents go to [stateStore] — by default, a
  /// [ForgeFileStateStore] over the workspace given to [initialize].
  DefaultWorkspaceStateManager({ForgeStateStore? stateStore})
    : _givenStore = stateStore;

  static bool debugEnabled = false;

  final ForgeStateStore? _givenStore;

  TomFileSystem? _fs;
  ForgeCoalescedStateWriter? _writer;
  bool _initialized = false;

  /// The writer [flushed] waits for; kept after [dispose].
  ForgeCoalescedStateWriter? _flushWriter;

  /// The store of the current workspace.
  ForgeStateStore get stateStore {
    _ensureInitialized();
    return _writer!.store;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  TomFileSystem get fileSystem {
    _ensureInitialized();
    return _fs!;
  }

  @override
  Uri get forgeDirectory => fileSystem.uriOf('.forge/');

  static void _log(String message) {
    if (debugEnabled) {
      debugPrint('[WorkspaceStateManager] $message');
    }
  }

  // ── Initialize ──

  /// The prefixes of the keys this manager writes.
  static const _keyPrefixes = ['config.json', 'state/', 'revisions/', 'undo/'];

  @override
  Future<bool> initialize(TomFileSystem workspace) async {
    final given = _givenStore;
    final bool created;
    final ForgeStateStore store;
    if (given == null) {
      final files = ForgeFileStateStore(workspace);
      created = !await workspace.exists(workspace.uriOf('.forge/'));
      await files.ensureFolder('state/editors');
      await files.ensureFolder('revisions');
      await files.ensureFolder('undo');
      store = files;
    } else {
      var empty = true;
      for (final prefix in _keyPrefixes) {
        if ((await given.keys(prefix: prefix)).isNotEmpty) {
          empty = false;
          break;
        }
      }
      created = empty;
      store = given;
    }
    _fs = workspace;
    final writer = ForgeCoalescedStateWriter(store, open: true);
    _writer = writer;
    _flushWriter = writer;
    _initialized = true;
    _log('initialized at ${workspace.uriOf('.forge/')} (created=$created)');
    return created;
  }

  // ── Open applications ──

  @override
  Future<void> saveOpenApplications(Map<String, Object?> snapshot) async {
    final store = _store;
    // The store writes atomically: a reader never sees half a document.
    await _write(store, 'state/applications.json', snapshot);
    _log('saved open applications');
  }

  @override
  Future<Map<String, Object?>?> loadOpenApplications() =>
      _readObject(_store, 'state/applications.json');

  // ── Per-editor state ──

  @override
  Future<void> saveEditorState(
    Uri editorUri,
    Map<String, dynamic> state,
  ) async {
    final store = _store;
    // Include the original URI for reference.
    state['_uri'] = editorUri.toString();
    await _write(store, 'state/editors/${_uriHash(editorUri)}.json', state);
  }

  @override
  Future<Map<String, dynamic>?> loadEditorState(Uri editorUri) =>
      _readObject(_store, 'state/editors/${_uriHash(editorUri)}.json');

  // ── Revisions ──

  @override
  Future<String?> createRevision(Uri fileUri, String content) async {
    final store = _store;
    final hash = _uriHash(fileUri);

    // De-duplicate: check last revision content.
    final manifest = await _loadManifest(store, hash);
    if (manifest.isNotEmpty &&
        await _read(store, 'revisions/$hash/${manifest.last}.snapshot') ==
            content) {
      _log('revision skipped (identical) for $fileUri');
      return null;
    }

    final revisionId = DateTime.now().millisecondsSinceEpoch.toString();
    await _write(store, 'revisions/$hash/$revisionId.snapshot', content);
    manifest.add(revisionId);
    await _saveManifest(store, hash, manifest);

    _log('created revision $revisionId for $fileUri');
    return revisionId;
  }

  @override
  Future<List<String>> listRevisions(Uri fileUri) async {
    final manifest = await _loadManifest(_store, _uriHash(fileUri));
    return manifest.reversed.toList();
  }

  @override
  Future<String?> readRevision(Uri fileUri, String revisionId) =>
      _read(_store, 'revisions/${_uriHash(fileUri)}/$revisionId.snapshot');

  @override
  Future<void> deleteRevision(Uri fileUri, String revisionId) async {
    final store = _store;
    final hash = _uriHash(fileUri);
    await _delete(store, 'revisions/$hash/$revisionId.snapshot');
    final manifest = await _loadManifest(store, hash);
    manifest.remove(revisionId);
    await _saveManifest(store, hash, manifest);
    _log('deleted revision $revisionId for $fileUri');
  }

  @override
  Future<int> pruneRevisions(Uri fileUri, {int maxRevisions = 50}) async {
    final store = _store;
    final hash = _uriHash(fileUri);
    final manifest = await _loadManifest(store, hash);
    if (manifest.length <= maxRevisions) return 0;

    final toRemove = manifest.sublist(0, manifest.length - maxRevisions);
    for (final id in toRemove) {
      await _delete(store, 'revisions/$hash/$id.snapshot');
    }
    await _saveManifest(
      store,
      hash,
      manifest.sublist(manifest.length - maxRevisions),
    );

    _log('pruned ${toRemove.length} revisions for $fileUri');
    return toRemove.length;
  }

  // ── Undo persistence ──

  @override
  Future<void> saveUndoHistory(
    Uri fileUri,
    List<Map<String, dynamic>> entries,
  ) async {
    final store = _store;
    await _write(store, 'undo/${_uriHash(fileUri)}.json', {
      'uri': fileUri.toString(),
      'entries': entries,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> loadUndoHistory(Uri fileUri) async {
    final data = await _readObject(_store, 'undo/${_uriHash(fileUri)}.json');
    final entries = data?['entries'];
    return entries is List ? entries.cast<Map<String, dynamic>>() : [];
  }

  // ── Configuration ──

  @override
  Future<void> saveConfig(Map<String, dynamic> configData) async {
    final store = _store;
    await _write(store, 'config.json', configData);
    _log('saved config');
  }

  @override
  Future<Map<String, dynamic>?> loadConfig() =>
      _readObject(_store, 'config.json');

  // ── Per-application state ──

  @override
  Future<void> saveApplicationState(
    String appId,
    Map<String, dynamic> state,
  ) async {
    final store = _store;
    state['_appId'] = appId;
    await _write(store, 'state/apps/${_stringHash(appId)}.json', state);
    _log('saved application state for "$appId"');
  }

  @override
  Future<Map<String, dynamic>?> loadApplicationState(String appId) =>
      _readObject(_store, 'state/apps/${_stringHash(appId)}.json');

  @override
  Future<void> deleteApplicationState(String appId) =>
      _delete(_store, 'state/apps/${_stringHash(appId)}.json');

  @override
  Future<void> flushed() async {
    // The writer of the last initialize: the shell disposes this manager in
    // the frame it writes its state, and still asks for the flush.
    await _flushWriter?.flushed();
  }

  @override
  void dispose() {
    _fs = null;
    _writer = null;
    _initialized = false;
  }

  // ── Private helpers ──

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'WorkspaceStateManager not initialized. Call initialize() first.',
      );
    }
  }

  /// The writer of the current workspace.
  ForgeCoalescedStateWriter get _store {
    _ensureInitialized();
    return _writer!;
  }

  static Future<void> _write(
    ForgeCoalescedStateWriter store,
    String key,
    Object document,
  ) => store.write(key, document);

  /// The text of [key], or null when it does not exist or is not text;
  /// after the writes of [key] started before have ended.
  static Future<String?> _read(
    ForgeCoalescedStateWriter store,
    String key,
  ) async {
    final document = await store.read(key);
    return document is String ? document : null;
  }

  /// The JSON document of [key]: a store that keeps maps and lists as
  /// their JSON text (shared_preferences) answers the text, decoded here.
  static Future<Object?> _readJson(
    ForgeCoalescedStateWriter store,
    String key,
  ) async {
    final document = await store.read(key);
    if (document is! String) return document;
    try {
      return jsonDecode(document);
    } on FormatException catch (e) {
      _log('decode $key failed: $e');
      return null;
    }
  }

  /// The JSON object of [key], or null when it is absent, unreadable or
  /// not an object.
  static Future<Map<String, dynamic>?> _readObject(
    ForgeCoalescedStateWriter store,
    String key,
  ) async {
    final document = await _readJson(store, key);
    if (document is Map<String, dynamic>) return document;
    if (document is Map) {
      try {
        return Map<String, dynamic>.from(document);
      } on TypeError {
        return null;
      }
    }
    return null;
  }

  static Future<void> _delete(ForgeCoalescedStateWriter store, String key) =>
      store.write(key, null);

  static String _uriHash(Uri uri) => _stringHash(uri.toString());

  /// A stable hash of [s] without a crypto dependency: the string's and its
  /// reverse's hash codes, for collision resistance.
  static String _stringHash(String s) {
    final h1 = s.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    final h2 = s
        .split('')
        .reversed
        .join()
        .hashCode
        .toUnsigned(32)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$h1$h2';
  }

  static Future<List<String>> _loadManifest(
    ForgeCoalescedStateWriter store,
    String uriHash,
  ) async {
    final data = await _readJson(store, 'revisions/$uriHash/manifest.json');
    // A damaged manifest counts as empty.
    if (data is List) return [for (final id in data) id.toString()];
    return [];
  }

  static Future<void> _saveManifest(
    ForgeCoalescedStateWriter store,
    String uriHash,
    List<String> ids,
  ) => _write(store, 'revisions/$uriHash/manifest.json', List<String>.of(ids));
}

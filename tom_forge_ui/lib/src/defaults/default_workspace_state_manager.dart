import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_file_system/tom_file_system.dart';

import '../services/forge_workspace_state_manager.dart';

/// Default implementation of [ForgeWorkspaceStateManager], over the
/// workspace's [TomFileSystem].
///
/// Keeps a `.forge/` directory in the workspace with the following
/// structure:
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
///
/// A state file that cannot be read or is of another shape counts as absent
/// (no migrations: the state is per machine).
///
/// Every operation takes the file system once, before its first await, and
/// works with it to the end: the shell writes state at exit and disposes
/// this manager in the same frame, so a write in flight must not look the
/// file system up again.
class DefaultWorkspaceStateManager implements ForgeWorkspaceStateManager {
  static bool debugEnabled = false;

  TomFileSystem? _fs;
  bool _initialized = false;

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

  @override
  Future<bool> initialize(TomFileSystem workspace) async {
    final existed = await workspace.exists(workspace.uriOf('.forge/'));
    await _folder(workspace, 'state/editors');
    await _folder(workspace, 'revisions');
    await _folder(workspace, 'undo');
    _fs = workspace;
    _initialized = true;
    _log('initialized at ${workspace.uriOf('.forge/')} (created=${!existed})');
    return !existed;
  }

  // ── Open applications ──

  @override
  Future<void> saveOpenApplications(Map<String, Object?> snapshot) async {
    final fs = fileSystem;
    // The file system writes atomically: a reader never sees half a file.
    await _write(fs, 'state/applications.json', _encodeJson(snapshot));
    _log('saved open applications');
  }

  @override
  Future<Map<String, Object?>?> loadOpenApplications() =>
      _readObject(fileSystem, 'state/applications.json');

  // ── Per-editor state ──

  @override
  Future<void> saveEditorState(
    Uri editorUri,
    Map<String, dynamic> state,
  ) async {
    final fs = fileSystem;
    // Include the original URI for reference.
    state['_uri'] = editorUri.toString();
    await _write(
      fs,
      'state/editors/${_uriHash(editorUri)}.json',
      _encodeJson(state),
    );
  }

  @override
  Future<Map<String, dynamic>?> loadEditorState(Uri editorUri) =>
      _readObject(fileSystem, 'state/editors/${_uriHash(editorUri)}.json');

  // ── Revisions ──

  @override
  Future<String?> createRevision(Uri fileUri, String content) async {
    final fs = fileSystem;
    final hash = _uriHash(fileUri);

    // De-duplicate: check last revision content.
    final manifest = await _loadManifest(fs, hash);
    if (manifest.isNotEmpty &&
        await _read(fs, 'revisions/$hash/${manifest.last}.snapshot') ==
            content) {
      _log('revision skipped (identical) for $fileUri');
      return null;
    }

    final revisionId = DateTime.now().millisecondsSinceEpoch.toString();
    await _write(fs, 'revisions/$hash/$revisionId.snapshot', content);
    manifest.add(revisionId);
    await _saveManifest(fs, hash, manifest);

    _log('created revision $revisionId for $fileUri');
    return revisionId;
  }

  @override
  Future<List<String>> listRevisions(Uri fileUri) async {
    final manifest = await _loadManifest(fileSystem, _uriHash(fileUri));
    return manifest.reversed.toList();
  }

  @override
  Future<String?> readRevision(Uri fileUri, String revisionId) => _read(
    fileSystem,
    'revisions/${_uriHash(fileUri)}/$revisionId.snapshot',
  );

  @override
  Future<void> deleteRevision(Uri fileUri, String revisionId) async {
    final fs = fileSystem;
    final hash = _uriHash(fileUri);
    await _delete(fs, 'revisions/$hash/$revisionId.snapshot');
    final manifest = await _loadManifest(fs, hash);
    manifest.remove(revisionId);
    await _saveManifest(fs, hash, manifest);
    _log('deleted revision $revisionId for $fileUri');
  }

  @override
  Future<int> pruneRevisions(Uri fileUri, {int maxRevisions = 50}) async {
    final fs = fileSystem;
    final hash = _uriHash(fileUri);
    final manifest = await _loadManifest(fs, hash);
    if (manifest.length <= maxRevisions) return 0;

    final toRemove = manifest.sublist(0, manifest.length - maxRevisions);
    for (final id in toRemove) {
      await _delete(fs, 'revisions/$hash/$id.snapshot');
    }
    await _saveManifest(
      fs,
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
    final fs = fileSystem;
    await _write(
      fs,
      'undo/${_uriHash(fileUri)}.json',
      _encodeJson({'uri': fileUri.toString(), 'entries': entries}),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadUndoHistory(Uri fileUri) async {
    final data = await _readObject(
      fileSystem,
      'undo/${_uriHash(fileUri)}.json',
    );
    final entries = data?['entries'];
    return entries is List ? entries.cast<Map<String, dynamic>>() : [];
  }

  // ── Configuration ──

  @override
  Future<void> saveConfig(Map<String, dynamic> configData) async {
    final fs = fileSystem;
    await _write(fs, 'config.json', _encodeJson(configData));
    _log('saved config');
  }

  @override
  Future<Map<String, dynamic>?> loadConfig() =>
      _readObject(fileSystem, 'config.json');

  // ── Per-application state ──

  @override
  Future<void> saveApplicationState(
    String appId,
    Map<String, dynamic> state,
  ) async {
    final fs = fileSystem;
    state['_appId'] = appId;
    await _write(
      fs,
      'state/apps/${_stringHash(appId)}.json',
      _encodeJson(state),
    );
    _log('saved application state for "$appId"');
  }

  @override
  Future<Map<String, dynamic>?> loadApplicationState(String appId) =>
      _readObject(fileSystem, 'state/apps/${_stringHash(appId)}.json');

  @override
  Future<void> deleteApplicationState(String appId) =>
      _delete(fileSystem, 'state/apps/${_stringHash(appId)}.json');

  @override
  void dispose() {
    _fs = null;
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

  /// The URI of [relative] under `.forge/`.
  static Uri _at(TomFileSystem fs, String relative) =>
      fs.uriOf('.forge/$relative');

  /// Makes the folder [relative] under `.forge/` (and its parents).
  static Future<void> _folder(TomFileSystem fs, String relative) async {
    final uri = _at(fs, relative.endsWith('/') ? relative : '$relative/');
    if (!await fs.exists(uri)) await fs.create(uri, directory: true);
  }

  static Future<void> _write(
    TomFileSystem fs,
    String relative,
    String text,
  ) async {
    final slash = relative.lastIndexOf('/');
    if (slash > 0) await _folder(fs, relative.substring(0, slash));
    await fs.writeText(_at(fs, relative), text);
  }

  /// The text of [relative], or null when it does not exist or cannot be
  /// read.
  static Future<String?> _read(TomFileSystem fs, String relative) async {
    final uri = _at(fs, relative);
    try {
      if (!await fs.exists(uri)) return null;
      return await fs.readText(uri);
    } on Exception catch (e) {
      _log('read $relative failed: $e');
      return null;
    }
  }

  /// The JSON object in [relative], or null when it is absent, unreadable or
  /// not an object.
  static Future<Map<String, dynamic>?> _readObject(
    TomFileSystem fs,
    String relative,
  ) async {
    final text = await _read(fs, relative);
    if (text == null) return null;
    try {
      final data = jsonDecode(text);
      return data is Map<String, dynamic> ? data : null;
    } on FormatException catch (e) {
      _log('decode $relative failed: $e');
      return null;
    }
  }

  static Future<void> _delete(TomFileSystem fs, String relative) async {
    final uri = _at(fs, relative);
    if (await fs.exists(uri)) await fs.delete(uri);
  }

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
    TomFileSystem fs,
    String uriHash,
  ) async {
    final text = await _read(fs, 'revisions/$uriHash/manifest.json');
    if (text == null) return [];
    try {
      final data = jsonDecode(text);
      if (data is List) return data.cast<String>();
    } on FormatException {
      // A damaged manifest counts as empty.
    }
    return [];
  }

  static Future<void> _saveManifest(
    TomFileSystem fs,
    String uriHash,
    List<String> ids,
  ) => _write(fs, 'revisions/$uriHash/manifest.json', _encodeJson(ids));

  static String _encodeJson(Object data) =>
      const JsonEncoder.withIndent('  ').convert(data);
}

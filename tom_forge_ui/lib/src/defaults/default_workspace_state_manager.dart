import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/forge_workspace_state_manager.dart';

/// Default implementation of [ForgeWorkspaceStateManager].
///
/// Manages a `.forge/` directory on disk with the following structure:
/// ```
/// .forge/
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
class DefaultWorkspaceStateManager implements ForgeWorkspaceStateManager {
  static bool debugEnabled = false;

  String? _forgeDir;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  String get forgeDirectoryPath => _forgeDir ?? '';

  static void _log(String message) {
    if (debugEnabled) {
      debugPrint('[WorkspaceStateManager] $message');
    }
  }

  // ── Initialize ──

  @override
  Future<bool> initialize(String workspaceRootPath) async {
    _forgeDir = '$workspaceRootPath/.forge';
    final dir = Directory(_forgeDir!);
    final existed = await dir.exists();

    if (!existed) {
      await dir.create(recursive: true);
    }

    // Ensure sub-directories exist.
    await Directory('$_forgeDir/state/editors').create(recursive: true);
    await Directory('$_forgeDir/revisions').create(recursive: true);
    await Directory('$_forgeDir/undo').create(recursive: true);

    _initialized = true;
    _log('initialized at $_forgeDir (created=${!existed})');
    return !existed;
  }

  // ── Walk-up detection ──

  @override
  Future<String?> detectWorkspaceRoot(String startPath) async {
    var current = Directory(startPath);
    // Walk up at most 20 levels to avoid infinite loops.
    for (var i = 0; i < 20; i++) {
      final forgeDir = Directory('${current.path}/.forge');
      if (await forgeDir.exists()) {
        return current.path;
      }
      final parent = current.parent;
      if (parent.path == current.path) break; // reached filesystem root
      current = parent;
    }
    return null;
  }

  // ── Open applications ──

  @override
  Future<void> saveOpenApplications(Map<String, Object?> snapshot) async {
    _ensureInitialized();
    await Directory('$_forgeDir/state').create(recursive: true);
    // Written beside and renamed over, so a reader never sees half a file.
    final file = File('$_forgeDir/state/applications.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(_encodeJson(snapshot), flush: true);
    await temp.rename(file.path);
    _log('saved open applications');
  }

  @override
  Future<Map<String, Object?>?> loadOpenApplications() async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/applications.json');
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      _log('load open applications failed: $e');
      return null;
    }
  }

  // ── Per-editor state ──

  @override
  Future<void> saveEditorState(
      Uri editorUri, Map<String, dynamic> state) async {
    _ensureInitialized();
    final hash = _uriHash(editorUri);
    final file = File('$_forgeDir/state/editors/$hash.json');
    // Include the original URI for reference.
    state['_uri'] = editorUri.toString();
    await file.writeAsString(_encodeJson(state));
  }

  @override
  Future<Map<String, dynamic>?> loadEditorState(Uri editorUri) async {
    _ensureInitialized();
    final hash = _uriHash(editorUri);
    final file = File('$_forgeDir/state/editors/$hash.json');
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      _log('load editor state failed for $editorUri: $e');
      return null;
    }
  }

  // ── Revisions ──

  @override
  Future<String?> createRevision(Uri fileUri, String content) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final revDir = Directory('$_forgeDir/revisions/$hash');
    if (!await revDir.exists()) {
      await revDir.create(recursive: true);
    }

    // De-duplicate: check last revision content.
    final manifest = await _loadManifest(hash);
    if (manifest.isNotEmpty) {
      final lastId = manifest.last;
      final lastFile = File('${revDir.path}/$lastId.snapshot');
      if (await lastFile.exists()) {
        final lastContent = await lastFile.readAsString();
        if (lastContent == content) {
          _log('revision skipped (identical) for $fileUri');
          return null;
        }
      }
    }

    final revisionId = DateTime.now().millisecondsSinceEpoch.toString();
    final snapshotFile = File('${revDir.path}/$revisionId.snapshot');
    await snapshotFile.writeAsString(content);

    manifest.add(revisionId);
    await _saveManifest(hash, manifest);

    _log('created revision $revisionId for $fileUri');
    return revisionId;
  }

  @override
  Future<List<String>> listRevisions(Uri fileUri) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final manifest = await _loadManifest(hash);
    return manifest.reversed.toList();
  }

  @override
  Future<String?> readRevision(Uri fileUri, String revisionId) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final file = File('$_forgeDir/revisions/$hash/$revisionId.snapshot');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> deleteRevision(Uri fileUri, String revisionId) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final file = File('$_forgeDir/revisions/$hash/$revisionId.snapshot');
    if (await file.exists()) {
      await file.delete();
    }
    final manifest = await _loadManifest(hash);
    manifest.remove(revisionId);
    await _saveManifest(hash, manifest);
    _log('deleted revision $revisionId for $fileUri');
  }

  @override
  Future<int> pruneRevisions(Uri fileUri, {int maxRevisions = 50}) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final manifest = await _loadManifest(hash);
    if (manifest.length <= maxRevisions) return 0;

    final toRemove = manifest.sublist(0, manifest.length - maxRevisions);
    for (final id in toRemove) {
      final file = File('$_forgeDir/revisions/$hash/$id.snapshot');
      if (await file.exists()) {
        await file.delete();
      }
    }
    final kept = manifest.sublist(manifest.length - maxRevisions);
    await _saveManifest(hash, kept);

    _log('pruned ${toRemove.length} revisions for $fileUri');
    return toRemove.length;
  }

  // ── Undo persistence ──

  @override
  Future<void> saveUndoHistory(
      Uri fileUri, List<Map<String, dynamic>> entries) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final file = File('$_forgeDir/undo/$hash.json');
    await file.writeAsString(_encodeJson({
      'uri': fileUri.toString(),
      'entries': entries,
    }));
  }

  @override
  Future<List<Map<String, dynamic>>> loadUndoHistory(Uri fileUri) async {
    _ensureInitialized();
    final hash = _uriHash(fileUri);
    final file = File('$_forgeDir/undo/$hash.json');
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is Map<String, dynamic> && data['entries'] is List) {
        return (data['entries'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _log('load undo history failed for $fileUri: $e');
    }
    return [];
  }

  // ── Configuration ──

  @override
  Future<void> saveConfig(Map<String, dynamic> configData) async {
    _ensureInitialized();
    final file = File('$_forgeDir/config.json');
    await file.writeAsString(_encodeJson(configData));
    _log('saved config');
  }

  @override
  Future<Map<String, dynamic>?> loadConfig() async {
    _ensureInitialized();
    final file = File('$_forgeDir/config.json');
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      _log('load config failed: $e');
      return null;
    }
  }

  // ── Gitignore ──

  @override
  Future<bool> isForgeInGitignore(String workspaceRootPath) async {
    final file = File('$workspaceRootPath/.gitignore');
    if (!await file.exists()) return false;
    final content = await file.readAsString();
    return content.split('\n').any((line) {
      final trimmed = line.trim();
      return trimmed == '.forge' || trimmed == '.forge/';
    });
  }

  @override
  Future<bool> suggestGitignore(String workspaceRootPath) async {
    if (await isForgeInGitignore(workspaceRootPath)) return false;

    final file = File('$workspaceRootPath/.gitignore');
    String content;
    if (await file.exists()) {
      content = await file.readAsString();
      if (!content.endsWith('\n')) content += '\n';
      content += '.forge/\n';
    } else {
      content = '# Forge workspace state\n.forge/\n';
    }
    await file.writeAsString(content);
    _log('added .forge/ to .gitignore');
    return true;
  }

  // ── Per-application state ──

  @override
  Future<void> saveApplicationState(
    String appId,
    Map<String, dynamic> state,
  ) async {
    _ensureInitialized();
    // Resolved before the first await: the shell writes every application's
    // state at exit and disposes this manager in the same frame.
    final apps = Directory('$_forgeDir/state/apps');
    final file = File('${apps.path}/${_stringHash(appId)}.json');
    await apps.create(recursive: true);
    state['_appId'] = appId;
    await file.writeAsString(_encodeJson(state));
    _log('saved application state for "$appId"');
  }

  @override
  Future<Map<String, dynamic>?> loadApplicationState(String appId) async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/apps/${_stringHash(appId)}.json');
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      _log('load application state failed for "$appId": $e');
      return null;
    }
  }

  @override
  Future<void> deleteApplicationState(String appId) async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/apps/${_stringHash(appId)}.json');
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    _forgeDir = null;
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

  String _uriHash(Uri uri) {
    // Simple stable hash: SHA-like hex via hashCode pairs to avoid
    // external crypto dependency. Uses the full URI string hashed in
    // two overlapping windows for collision resistance.
    final s = uri.toString();
    final h1 = s.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    final h2 =
        s.split('').reversed.join().hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return '$h1$h2';
  }

  String _stringHash(String s) {
    final h1 = s.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    final h2 =
        s.split('').reversed.join().hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return '$h1$h2';
  }

  Future<List<String>> _loadManifest(String uriHash) async {
    final file = File('$_forgeDir/revisions/$uriHash/manifest.json');
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is List) return data.cast<String>();
    } catch (_) {}
    return [];
  }

  Future<void> _saveManifest(String uriHash, List<String> ids) async {
    final file = File('$_forgeDir/revisions/$uriHash/manifest.json');
    await file.writeAsString(_encodeJson(ids));
  }

  String _encodeJson(Object data) {
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

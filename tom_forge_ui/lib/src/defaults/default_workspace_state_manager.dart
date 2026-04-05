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
///     layout.json
///     open-editors.json
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

  // ── Layout state ──

  @override
  Future<void> saveLayoutState(Map<String, dynamic> layoutData) async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/layout.json');
    await file.writeAsString(_encodeJson(layoutData));
    _log('saved layout state');
  }

  @override
  Future<Map<String, dynamic>?> loadLayoutState() async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/layout.json');
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      _log('load layout state failed: $e');
      return null;
    }
  }

  // ── Open editors ──

  @override
  Future<void> saveOpenEditors(List<String> editorUris) async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/open-editors.json');
    await file.writeAsString(_encodeJson(editorUris));
    _log('saved ${editorUris.length} open editors');
  }

  @override
  Future<List<String>> loadOpenEditors() async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/open-editors.json');
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is List) return data.cast<String>();
    } catch (e) {
      _log('load open editors failed: $e');
    }
    return [];
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

  /// Saves the state of an application (open editors, active editor, layout).
  ///
  /// Stores in `.forge/state/apps/{app-hash}.json`.
  Future<void> saveApplicationState(
    String appTitle,
    Map<String, dynamic> state,
  ) async {
    _ensureInitialized();
    await Directory('$_forgeDir/state/apps').create(recursive: true);
    final hash = _stringHash(appTitle);
    final file = File('$_forgeDir/state/apps/$hash.json');
    state['_appTitle'] = appTitle;
    await file.writeAsString(_encodeJson(state));
    _log('saved application state for "$appTitle"');
  }

  /// Loads the saved state of an application.
  Future<Map<String, dynamic>?> loadApplicationState(String appTitle) async {
    _ensureInitialized();
    final hash = _stringHash(appTitle);
    final file = File('$_forgeDir/state/apps/$hash.json');
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      _log('load application state failed for "$appTitle": $e');
      return null;
    }
  }

  /// Returns a list of all saved application titles.
  Future<List<String>> listSavedApplications() async {
    _ensureInitialized();
    final dir = Directory('$_forgeDir/state/apps');
    if (!await dir.exists()) return [];

    final apps = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final data = jsonDecode(await entity.readAsString());
          if (data is Map<String, dynamic> && data['_appTitle'] is String) {
            apps.add(data['_appTitle'] as String);
          }
        } catch (_) {}
      }
    }
    return apps;
  }

  /// Saves the current active application title for restoration on next launch.
  Future<void> saveActiveApplicationTitle(String appTitle) async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/active-app.txt');
    await file.writeAsString(appTitle);
    _log('saved active application: "$appTitle"');
  }

  /// Loads the last active application title.
  Future<String?> loadActiveApplicationTitle() async {
    _ensureInitialized();
    final file = File('$_forgeDir/state/active-app.txt');
    if (!await file.exists()) return null;
    try {
      final title = await file.readAsString();
      return title.trim().isNotEmpty ? title.trim() : null;
    } catch (e) {
      _log('load active application title failed: $e');
      return null;
    }
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

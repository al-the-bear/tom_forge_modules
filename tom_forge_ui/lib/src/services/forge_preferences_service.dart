import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

/// Service for managing persistent preferences.
///
/// Uses SharedPreferences for platform-native storage.
/// Handles startup preferences, recent workspaces, and configuration settings.
class ForgePreferencesService extends ChangeNotifier {
  static const _keyLastWorkspace = 'forge.startup.lastWorkspacePath';
  static const _keyConfigMode = 'forge.startup.configMode';
  static const _keyRememberSettings = 'forge.startup.rememberSettings';
  static const _keyRecentWorkspaces = 'forge.startup.recentWorkspaces';
  static const _keyMaxRecentWorkspaces = 'forge.startup.maxRecentWorkspaces';
  static const _keyConfigDirectory = 'forge.startup.configDirectory';

  SharedPreferences? _prefs;
  ForgeStartupPreferences _startupPreferences = ForgeStartupPreferences();
  int _maxRecentWorkspaces = 10;
  String? _centralConfigDirectory;

  /// The currently loaded startup preferences.
  ForgeStartupPreferences get startupPreferences => _startupPreferences;

  /// Maximum number of recent workspaces to track.
  int get maxRecentWorkspaces => _maxRecentWorkspaces;
  set maxRecentWorkspaces(int value) {
    if (_maxRecentWorkspaces != value) {
      _maxRecentWorkspaces = value;
      _prefs?.setInt(_keyMaxRecentWorkspaces, value);
      // Trim the list if needed
      if (_startupPreferences.recentWorkspaces.length > value) {
        _startupPreferences.recentWorkspaces =
            _startupPreferences.recentWorkspaces.take(value).toList();
        _saveRecentWorkspaces();
      }
      notifyListeners();
    }
  }

  /// Central config directory (null = use workspace-local .forge/).
  String? get centralConfigDirectory => _centralConfigDirectory;
  set centralConfigDirectory(String? value) {
    if (_centralConfigDirectory != value) {
      _centralConfigDirectory = value;
      if (value != null) {
        _prefs?.setString(_keyConfigDirectory, value);
      } else {
        _prefs?.remove(_keyConfigDirectory);
      }
      notifyListeners();
    }
  }

  /// Gets the config directory for a given workspace.
  ///
  /// Returns either the central config directory or
  /// `{workspacePath}/.forge/` if using local config.
  String getConfigDirectory(String workspacePath) {
    if (_centralConfigDirectory != null) {
      return _centralConfigDirectory!;
    }
    return '$workspacePath/.forge';
  }

  /// Loads preferences from persistent storage.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    _startupPreferences = ForgeStartupPreferences(
      lastWorkspacePath: _prefs!.getString(_keyLastWorkspace),
      lastConfigMode: _prefs!.getString(_keyConfigMode),
      rememberSettings: _prefs!.getBool(_keyRememberSettings) ?? true,
      recentWorkspaces: _loadRecentWorkspaces(),
    );

    _maxRecentWorkspaces = _prefs!.getInt(_keyMaxRecentWorkspaces) ?? 10;
    _centralConfigDirectory = _prefs!.getString(_keyConfigDirectory);

    notifyListeners();
  }

  List<String> _loadRecentWorkspaces() {
    final jsonStr = _prefs!.getString(_keyRecentWorkspaces);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr);
      if (list is List) {
        return list.cast<String>();
      }
    } catch (_) {
      // Ignore parse errors
    }
    return [];
  }

  /// Saves all preferences to persistent storage.
  Future<void> save() async {
    if (_prefs == null) {
      await load();
    }

    if (_startupPreferences.lastWorkspacePath != null) {
      await _prefs!.setString(
          _keyLastWorkspace, _startupPreferences.lastWorkspacePath!);
    } else {
      await _prefs!.remove(_keyLastWorkspace);
    }

    if (_startupPreferences.lastConfigMode != null) {
      await _prefs!.setString(
          _keyConfigMode, _startupPreferences.lastConfigMode!);
    } else {
      await _prefs!.remove(_keyConfigMode);
    }

    await _prefs!.setBool(
        _keyRememberSettings, _startupPreferences.rememberSettings);
    await _saveRecentWorkspaces();
  }

  Future<void> _saveRecentWorkspaces() async {
    final jsonStr = jsonEncode(_startupPreferences.recentWorkspaces);
    await _prefs!.setString(_keyRecentWorkspaces, jsonStr);
  }

  /// Adds a workspace to the recent list.
  ///
  /// The workspace is moved to the front if already present.
  /// The list is trimmed to [maxRecentWorkspaces].
  Future<void> addRecentWorkspace(String path) async {
    final list = _startupPreferences.recentWorkspaces;

    // Remove if already present
    list.remove(path);

    // Add to front
    list.insert(0, path);

    // Trim to max
    if (list.length > _maxRecentWorkspaces) {
      _startupPreferences.recentWorkspaces =
          list.take(_maxRecentWorkspaces).toList();
    }

    // Update last workspace
    _startupPreferences.lastWorkspacePath = path;

    await _saveRecentWorkspaces();
    await _prefs?.setString(_keyLastWorkspace, path);
    notifyListeners();
  }

  /// Removes a workspace from the recent list.
  Future<void> removeRecentWorkspace(String path) async {
    _startupPreferences.recentWorkspaces.remove(path);
    await _saveRecentWorkspaces();
    notifyListeners();
  }

  /// Clears all recent workspaces.
  Future<void> clearRecentWorkspaces() async {
    _startupPreferences.recentWorkspaces.clear();
    _startupPreferences.lastWorkspacePath = null;
    await _saveRecentWorkspaces();
    await _prefs?.remove(_keyLastWorkspace);
    notifyListeners();
  }

  /// Creates a singleton instance with default settings.
  static final ForgePreferencesService instance = ForgePreferencesService();
}

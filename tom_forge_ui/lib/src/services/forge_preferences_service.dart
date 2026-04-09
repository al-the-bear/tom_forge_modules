import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextDefaults, ForgeTextSettings;

import '../actions/forge_shortcut_binding.dart';

/// Service for managing persistent preferences.
///
/// Uses SharedPreferences for platform-native storage.
/// Handles startup preferences, recent workspaces, and configuration settings.
class ForgePreferencesService extends ChangeNotifier {
  static bool debugEnabled = false;

  static const _keyLastWorkspace = 'forge.startup.lastWorkspacePath';
  static const _keyConfigMode = 'forge.startup.configMode';
  static const _keyRememberSettings = 'forge.startup.rememberSettings';
  static const _keyRecentWorkspaces = 'forge.startup.recentWorkspaces';
  static const _keyMaxRecentWorkspaces = 'forge.startup.maxRecentWorkspaces';
  static const _keyConfigDirectory = 'forge.startup.configDirectory';
  static const _keyEditorTextSettings = 'forge.editor.textSettings';
  static const _keyLayoutPanelSizes = 'forge.layout.panelSizes';
  static const _keyLayoutPanelVisibility = 'forge.layout.panelVisibility';
  static const _keyLayoutOpenEditors = 'forge.layout.openEditors';
  static const _keyLayoutSnapshot = 'forge.layout.snapshot';
  static const _keyThemeMode = 'forge.appearance.themeMode';
  static const _keyFileTypeDefaults = 'forge.files.typeDefaults';
  static const _keyShortcutOverrides = 'forge.shortcuts.overrides';
  static const _keyChordOverrides = 'forge.shortcuts.chordOverrides';
  static const _keyDeletedBindings = 'forge.shortcuts.deletedBindings';
  static const _keyTerminalDefaultShell = 'forge.terminal.defaultShell';
  static const _keyTerminalShellPaths = 'forge.terminal.shellPaths';
  static const _keyTerminalStartFolder = 'forge.terminal.startFolder';
  static const _keyTerminalScrollbackLines = 'forge.terminal.scrollbackLines';
  static const _keyTerminalFontFamily = 'forge.terminal.fontFamily';
  static const _keyTerminalFontSize = 'forge.terminal.fontSize';
  static const _keySearchConfig = 'forge.search.config';
  static const _keyEditorSpecificConfig = 'forge.editor.specificConfig';
  static const _keyDimPanelContentMinWidth =
      'forge.layout.dim.panelContentMinWidth';
  static const _keyDimLeftPanelDefaultWidth =
      'forge.layout.dim.leftPanelDefaultWidth';
  static const _keyDimRightPanelDefaultWidth =
      'forge.layout.dim.rightPanelDefaultWidth';
  static const _keyDimBottomPanelDefaultHeight =
      'forge.layout.dim.bottomPanelDefaultHeight';
  static const _keyDimDividerHitTarget = 'forge.layout.dim.dividerHitTarget';
  static const _keyReduceMotion = 'forge.appearance.reduceMotion';

  SharedPreferences? _prefs;
  ForgeStartupPreferences _startupPreferences = ForgeStartupPreferences();
  int _maxRecentWorkspaces = 10;
  String? _centralConfigDirectory;
  final Map<String, ForgeTextSettings> _editorTextSettings =
      <String, ForgeTextSettings>{};
  final Map<String, double> _layoutPanelSizes = <String, double>{};
  final Map<String, bool> _layoutPanelVisibility = <String, bool>{};
  Map<String, dynamic> _layoutSnapshot = <String, dynamic>{};
  final Map<String, String> _fileTypeDefaultEditors = <String, String>{};
  final Map<String, ForgeShortcutKey> _shortcutOverrides =
      <String, ForgeShortcutKey>{};
  final Map<String, ForgeChordKey> _chordOverrides =
      <String, ForgeChordKey>{};
  final Set<String> _deletedBindings = <String>{};
  List<String> _layoutOpenEditors = <String>[];
  ThemeMode _themeMode = ThemeMode.dark;
  String? _terminalDefaultShell;
  List<String> _terminalShellPaths = <String>[];
  String _terminalStartFolder = 'workspace';
  int _terminalScrollbackLines = 10000;
  String _terminalFontFamily = 'monospace';
  double _terminalFontSize = 14.0;
  ForgeSearchConfig _searchConfig = const ForgeSearchConfig();
  final Map<String, Map<String, dynamic>> _editorSpecificConfig =
      <String, Map<String, dynamic>>{};
  double _panelContentMinWidth = 400.0;
  double _leftPanelDefaultWidth = 280.0;
  double _rightPanelDefaultWidth = 280.0;
  double _bottomPanelDefaultHeight = 200.0;
  double _dividerHitTarget = 14.0;
  bool _reduceMotion = false;
  bool _isLoaded = false;

  /// When true, layout restoration should skip workspace-level fallback.
  bool _layoutResetRequested = false;

  /// Whether a layout reset was requested (e.g. via the "Reset UI" checkbox).
  bool get layoutResetRequested => _layoutResetRequested;

  /// Clears the reset-requested flag after layout restoration is complete.
  void clearLayoutResetRequest() {
    _layoutResetRequested = false;
  }

  static void _log(String message) {
    if (debugEnabled) {
      debugPrint('[ForgePreferencesService] $message');
    }
  }

  /// The currently loaded startup preferences.
  ForgeStartupPreferences get startupPreferences => _startupPreferences;

  /// Whether preferences were loaded at least once.
  bool get isLoaded => _isLoaded;

  /// Snapshot of all persisted editor settings keyed by editor type id.
  Map<String, ForgeTextSettings> get editorTextSettings =>
      Map<String, ForgeTextSettings>.unmodifiable(_editorTextSettings);

  /// Reads text settings for the given editor type.
  ForgeTextSettings getEditorTextSettings(String editorTypeId) {
    return _editorTextSettings[editorTypeId] ?? const ForgeTextSettings();
  }

  /// Stores text settings for an editor type.
  void setEditorTextSettings(String editorTypeId, ForgeTextSettings settings) {
    final previous = _editorTextSettings[editorTypeId];
    if (previous == settings) {
      return;
    }
    _editorTextSettings[editorTypeId] = settings;
    _log('updated editor settings for $editorTypeId');
    notifyListeners();
  }

  /// Reads editor-specific configuration map for the given editor type.
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId) {
    return Map<String, dynamic>.from(
        _editorSpecificConfig[editorTypeId] ?? <String, dynamic>{});
  }

  /// Stores editor-specific configuration map for an editor type.
  void setEditorSpecificConfig(
      String editorTypeId, Map<String, dynamic> config) {
    _editorSpecificConfig[editorTypeId] = Map<String, dynamic>.from(config);
    _log('updated editor specific config for $editorTypeId');
    notifyListeners();
  }

  /// Preferred default editor ids keyed by file extension (for example: .md).
  Map<String, String> get fileTypeDefaultEditors =>
      Map<String, String>.unmodifiable(_fileTypeDefaultEditors);

  /// Sets preferred editor id for a file extension.
  void setFileTypeDefaultEditor(String extension, String editorTypeId) {
    final normalized = _normalizeExtension(extension);
    if (normalized.isEmpty) {
      return;
    }
    if (_fileTypeDefaultEditors[normalized] == editorTypeId) {
      return;
    }
    _fileTypeDefaultEditors[normalized] = editorTypeId;
    notifyListeners();
  }

  /// Shortcut overrides keyed by action id.
  Map<String, ForgeShortcutKey> get shortcutOverrides =>
      Map<String, ForgeShortcutKey>.unmodifiable(_shortcutOverrides);

  /// Sets a shortcut override for a specific action id.
  void setShortcutOverride(String actionId, ForgeShortcutKey key) {
    if (_shortcutOverrides[actionId] == key) {
      return;
    }
    _shortcutOverrides[actionId] = key;
    notifyListeners();
  }

  /// Removes a shortcut override for an action id.
  void removeShortcutOverride(String actionId) {
    if (_shortcutOverrides.remove(actionId) != null) {
      notifyListeners();
    }
  }

  /// Clears all shortcut overrides.
  void clearShortcutOverrides() {
    if (_shortcutOverrides.isEmpty) {
      return;
    }
    _shortcutOverrides.clear();
    notifyListeners();
  }

  /// Chord overrides keyed by action id.
  Map<String, ForgeChordKey> get chordOverrides =>
      Map<String, ForgeChordKey>.unmodifiable(_chordOverrides);

  /// Sets a chord override for a specific action id.
  void setChordOverride(String actionId, ForgeChordKey chord) {
    _chordOverrides[actionId] = chord;
    notifyListeners();
  }

  /// Removes a chord override for an action id.
  void removeChordOverride(String actionId) {
    if (_chordOverrides.remove(actionId) != null) {
      notifyListeners();
    }
  }

  /// Clears all chord overrides.
  void clearChordOverrides() {
    if (_chordOverrides.isEmpty) return;
    _chordOverrides.clear();
    notifyListeners();
  }

  /// Action IDs that were explicitly deleted by the user.
  Set<String> get deletedBindings => Set.unmodifiable(_deletedBindings);

  /// Marks a binding as deleted so it is not re-registered on restart.
  void addDeletedBinding(String actionId) {
    if (_deletedBindings.add(actionId)) {
      notifyListeners();
    }
  }

  /// Removes a binding from the deleted set (un-deletes it).
  void removeDeletedBinding(String actionId) {
    if (_deletedBindings.remove(actionId)) {
      notifyListeners();
    }
  }

  // ── Terminal preferences ──

  /// Default shell executable path (null = platform default).
  String? get terminalDefaultShell => _terminalDefaultShell;
  set terminalDefaultShell(String? value) {
    if (_terminalDefaultShell != value) {
      _terminalDefaultShell = value;
      notifyListeners();
    }
  }

  /// List of available shell paths the user can choose from.
  List<String> get terminalShellPaths =>
      List<String>.unmodifiable(_terminalShellPaths);
  set terminalShellPaths(List<String> value) {
    _terminalShellPaths = List<String>.from(value);
    notifyListeners();
  }

  /// Terminal start folder behavior: 'workspace', 'home', or 'lastUsed'.
  String get terminalStartFolder => _terminalStartFolder;
  set terminalStartFolder(String value) {
    if (_terminalStartFolder != value) {
      _terminalStartFolder = value;
      notifyListeners();
    }
  }

  /// Terminal scrollback buffer lines.
  int get terminalScrollbackLines => _terminalScrollbackLines;
  set terminalScrollbackLines(int value) {
    if (_terminalScrollbackLines != value) {
      _terminalScrollbackLines = value;
      notifyListeners();
    }
  }

  /// Terminal font family.
  String get terminalFontFamily => _terminalFontFamily;
  set terminalFontFamily(String value) {
    if (_terminalFontFamily != value) {
      _terminalFontFamily = value;
      notifyListeners();
    }
  }

  /// Terminal font size.
  double get terminalFontSize => _terminalFontSize;
  set terminalFontSize(double value) {
    if (_terminalFontSize != value) {
      _terminalFontSize = value;
      notifyListeners();
    }
  }

  // ── Layout state persistence ──

  /// Panel sizes keyed by panel location name (left, right, bottom).
  Map<String, double> get layoutPanelSizes =>
      Map<String, double>.unmodifiable(_layoutPanelSizes);

  /// Sets a panel size by location name.
  void setLayoutPanelSize(String panelName, double size) {
    _layoutPanelSizes[panelName] = size;
  }

  /// Panel visibility keyed by panel location name.
  Map<String, bool> get layoutPanelVisibility =>
      Map<String, bool>.unmodifiable(_layoutPanelVisibility);

  /// Sets a panel visibility by location name.
  void setLayoutPanelVisibility(String panelName, bool visible) {
    _layoutPanelVisibility[panelName] = visible;
  }

  /// List of open editor URIs that were active when last saved.
  List<String> get layoutOpenEditors =>
      List<String>.unmodifiable(_layoutOpenEditors);

  /// Sets the list of open editor URIs to persist.
  void setLayoutOpenEditors(List<String> editorUris) {
    _layoutOpenEditors = List<String>.from(editorUris);
  }

  /// Full layout snapshot (panels + middle panel tabs) used for
  /// complete layout persistence across restarts.
  Map<String, dynamic> get layoutSnapshot =>
      Map<String, dynamic>.unmodifiable(_layoutSnapshot);

  /// Sets full layout snapshot.
  void setLayoutSnapshot(Map<String, dynamic> snapshot) {
    _layoutSnapshot = Map<String, dynamic>.from(snapshot);
  }

  /// Clears all layout state, forcing a fresh UI on next launch.
  void clearLayoutState() {
    _layoutSnapshot.clear();
    _layoutPanelSizes.clear();
    _layoutPanelVisibility.clear();
    _layoutOpenEditors.clear();
    _layoutResetRequested = true;
  }

  /// The persisted theme mode (dark, light, or system).
  ThemeMode get themeMode => _themeMode;

  /// Sets and persists the theme mode.
  set themeMode(ThemeMode value) {
    if (_themeMode != value) {
      _themeMode = value;
      _prefs?.setString(_keyThemeMode, value.name);
      notifyListeners();
    }
  }

  /// Maximum number of recent workspaces to track.
  int get maxRecentWorkspaces => _maxRecentWorkspaces;
  set maxRecentWorkspaces(int value) {
    if (_maxRecentWorkspaces != value) {
      _maxRecentWorkspaces = value;
      _prefs?.setInt(_keyMaxRecentWorkspaces, value);
      // Trim the list if needed
      if (_startupPreferences.recentWorkspaces.length > value) {
        _startupPreferences.recentWorkspaces = _startupPreferences
            .recentWorkspaces
            .take(value)
            .toList();
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

  // ── Search configuration ──

  /// The current search configuration.
  ForgeSearchConfig get searchConfig => _searchConfig;

  /// Updates the search configuration and persists it.
  set searchConfig(ForgeSearchConfig value) {
    _searchConfig = value;
    _saveSearchConfig();
    notifyListeners();
  }

  ForgeSearchConfig _loadSearchConfig() {
    final jsonStr = _prefs!.getString(_keySearchConfig);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return const ForgeSearchConfig();
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return ForgeSearchConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return ForgeSearchConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const ForgeSearchConfig();
  }

  Future<void> _saveSearchConfig() async {
    await _prefs?.setString(
      _keySearchConfig,
      jsonEncode(_searchConfig.toJson()),
    );
  }

  // ── Layout dimensions ──

  double get panelContentMinWidth => _panelContentMinWidth;
  set panelContentMinWidth(double value) {
    _panelContentMinWidth = value.clamp(100, 2000);
    notifyListeners();
  }

  double get leftPanelDefaultWidth => _leftPanelDefaultWidth;
  set leftPanelDefaultWidth(double value) {
    _leftPanelDefaultWidth = value.clamp(100, 800);
    notifyListeners();
  }

  double get rightPanelDefaultWidth => _rightPanelDefaultWidth;
  set rightPanelDefaultWidth(double value) {
    _rightPanelDefaultWidth = value.clamp(100, 800);
    notifyListeners();
  }

  double get bottomPanelDefaultHeight => _bottomPanelDefaultHeight;
  set bottomPanelDefaultHeight(double value) {
    _bottomPanelDefaultHeight = value.clamp(50, 600);
    notifyListeners();
  }

  double get dividerHitTarget => _dividerHitTarget;
  set dividerHitTarget(double value) {
    _dividerHitTarget = value.clamp(4, 40);
    notifyListeners();
  }

  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    _reduceMotion = value;
    notifyListeners();
  }

  Map<String, Map<String, dynamic>> _loadEditorSpecificConfig() {
    final jsonStr = _prefs?.getString(_keyEditorSpecificConfig);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, Map<String, dynamic>>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(
            k.toString(),
            v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}));
      }
    } catch (_) {}
    return <String, Map<String, dynamic>>{};
  }

  Future<void> _saveEditorSpecificConfig() async {
    await _prefs?.setString(
      _keyEditorSpecificConfig,
      jsonEncode(_editorSpecificConfig),
    );
  }

  /// Loads preferences from persistent storage.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      _startupPreferences = ForgeStartupPreferences(
        lastWorkspacePath: _prefs!.getString(_keyLastWorkspace),
        lastConfigMode: _prefs!.getString(_keyConfigMode),
        rememberSettings: _prefs!.getBool(_keyRememberSettings) ?? true,
        recentWorkspaces: _loadRecentWorkspaces(),
      );

      _maxRecentWorkspaces = _prefs!.getInt(_keyMaxRecentWorkspaces) ?? 10;
      _centralConfigDirectory = _prefs!.getString(_keyConfigDirectory);
      _editorTextSettings
        ..clear()
        ..addAll(_loadEditorTextSettings());
      _layoutPanelSizes
        ..clear()
        ..addAll(_loadLayoutPanelSizes());
      _layoutPanelVisibility
        ..clear()
        ..addAll(_loadLayoutPanelVisibility());
      _layoutSnapshot = _loadLayoutSnapshot();
      _fileTypeDefaultEditors
        ..clear()
        ..addAll(_loadFileTypeDefaults());
      _shortcutOverrides
        ..clear()
        ..addAll(_loadShortcutOverrides());
      _chordOverrides
        ..clear()
        ..addAll(_loadChordOverrides());
      _deletedBindings
        ..clear()
        ..addAll(_loadDeletedBindings());
      _layoutOpenEditors = _loadLayoutOpenEditors();
      _themeMode = _loadThemeMode();
      _terminalDefaultShell = _prefs!.getString(_keyTerminalDefaultShell);
      _terminalShellPaths = _loadTerminalShellPaths();
      _terminalStartFolder =
          _prefs!.getString(_keyTerminalStartFolder) ?? 'workspace';
      _terminalScrollbackLines =
          _prefs!.getInt(_keyTerminalScrollbackLines) ?? 10000;
      _terminalFontFamily =
          _prefs!.getString(_keyTerminalFontFamily) ?? 'monospace';
      _terminalFontSize =
          (_prefs!.getDouble(_keyTerminalFontSize)) ?? 14.0;
      _searchConfig = _loadSearchConfig();
      _editorSpecificConfig
        ..clear()
        ..addAll(_loadEditorSpecificConfig());
      _panelContentMinWidth =
          _prefs!.getDouble(_keyDimPanelContentMinWidth) ?? 400.0;
      _leftPanelDefaultWidth =
          _prefs!.getDouble(_keyDimLeftPanelDefaultWidth) ?? 280.0;
      _rightPanelDefaultWidth =
          _prefs!.getDouble(_keyDimRightPanelDefaultWidth) ?? 280.0;
      _bottomPanelDefaultHeight =
          _prefs!.getDouble(_keyDimBottomPanelDefaultHeight) ?? 200.0;
      _dividerHitTarget =
          _prefs!.getDouble(_keyDimDividerHitTarget) ?? 14.0;
      _reduceMotion = _prefs!.getBool(_keyReduceMotion) ?? false;
      _isLoaded = true;
      _log(
        'loaded preferences with ${_editorTextSettings.length} editor settings entries',
      );

      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('[ForgePreferencesService] load failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
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
    try {
      if (_prefs == null) {
        await load();
      }

      if (_startupPreferences.lastWorkspacePath != null) {
        await _prefs!.setString(
          _keyLastWorkspace,
          _startupPreferences.lastWorkspacePath!,
        );
      } else {
        await _prefs!.remove(_keyLastWorkspace);
      }

      if (_startupPreferences.lastConfigMode != null) {
        await _prefs!.setString(
          _keyConfigMode,
          _startupPreferences.lastConfigMode!,
        );
      } else {
        await _prefs!.remove(_keyConfigMode);
      }

      await _prefs!.setBool(
        _keyRememberSettings,
        _startupPreferences.rememberSettings,
      );
      await _saveRecentWorkspaces();
      await _saveEditorTextSettings();
      await _saveLayoutPanelSizes();
      await _saveLayoutPanelVisibility();
      await _saveLayoutOpenEditors();
      await _saveLayoutSnapshot();
      await _saveFileTypeDefaults();
      await _saveShortcutOverrides();
      await _saveChordOverrides();
      await _saveDeletedBindings();
      await _prefs!.setString(_keyThemeMode, _themeMode.name);
      await _saveTerminalPreferences();
      await _saveSearchConfig();
      await _saveEditorSpecificConfig();
      await _saveLayoutDimensions();
      _log(
        'saved preferences with ${_editorTextSettings.length} editor settings entries',
      );
    } catch (error, stackTrace) {
      debugPrint('[ForgePreferencesService] save failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Future<void> _saveRecentWorkspaces() async {
    final jsonStr = jsonEncode(_startupPreferences.recentWorkspaces);
    await _prefs!.setString(_keyRecentWorkspaces, jsonStr);
  }

  List<String> _loadTerminalShellPaths() {
    final jsonStr = _prefs!.getString(_keyTerminalShellPaths);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String>[];
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> _saveTerminalPreferences() async {
    if (_terminalDefaultShell != null) {
      await _prefs!.setString(
        _keyTerminalDefaultShell,
        _terminalDefaultShell!,
      );
    } else {
      await _prefs!.remove(_keyTerminalDefaultShell);
    }
    await _prefs!.setString(
      _keyTerminalShellPaths,
      jsonEncode(_terminalShellPaths),
    );
    await _prefs!.setString(_keyTerminalStartFolder, _terminalStartFolder);
    await _prefs!.setInt(
      _keyTerminalScrollbackLines,
      _terminalScrollbackLines,
    );
    await _prefs!.setString(_keyTerminalFontFamily, _terminalFontFamily);
    await _prefs!.setDouble(_keyTerminalFontSize, _terminalFontSize);
  }

  Future<void> _saveLayoutDimensions() async {
    await _prefs!.setDouble(
      _keyDimPanelContentMinWidth,
      _panelContentMinWidth,
    );
    await _prefs!.setDouble(
      _keyDimLeftPanelDefaultWidth,
      _leftPanelDefaultWidth,
    );
    await _prefs!.setDouble(
      _keyDimRightPanelDefaultWidth,
      _rightPanelDefaultWidth,
    );
    await _prefs!.setDouble(
      _keyDimBottomPanelDefaultHeight,
      _bottomPanelDefaultHeight,
    );
    await _prefs!.setDouble(_keyDimDividerHitTarget, _dividerHitTarget);
    await _prefs!.setBool(_keyReduceMotion, _reduceMotion);
  }

  Map<String, ForgeTextSettings> _loadEditorTextSettings() {
    final jsonStr = _prefs!.getString(_keyEditorTextSettings);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, ForgeTextSettings>{};
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, ForgeTextSettings>{};
      }

      final result = <String, ForgeTextSettings>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map<String, dynamic>) {
          result[key] = _textSettingsFromMap(value);
        } else if (key is String && value is Map) {
          result[key] = _textSettingsFromMap(Map<String, dynamic>.from(value));
        }
      }
      return result;
    } catch (error, stackTrace) {
      debugPrint(
        '[ForgePreferencesService] parse editor settings failed: $error',
      );
      debugPrint('$stackTrace');
      return <String, ForgeTextSettings>{};
    }
  }

  Future<void> _saveEditorTextSettings() async {
    final serializable = <String, Map<String, dynamic>>{};
    for (final entry in _editorTextSettings.entries) {
      serializable[entry.key] = _textSettingsToMap(entry.value);
    }
    await _prefs!.setString(_keyEditorTextSettings, jsonEncode(serializable));
  }

  Map<String, double> _loadLayoutPanelSizes() {
    final jsonStr = _prefs!.getString(_keyLayoutPanelSizes);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, double>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        );
      }
    } catch (_) {}
    return <String, double>{};
  }

  Future<void> _saveLayoutPanelSizes() async {
    await _prefs!.setString(
      _keyLayoutPanelSizes,
      jsonEncode(_layoutPanelSizes),
    );
  }

  Map<String, bool> _loadLayoutPanelVisibility() {
    final jsonStr = _prefs!.getString(_keyLayoutPanelVisibility);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, bool>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key as String, value as bool),
        );
      }
    } catch (_) {}
    return <String, bool>{};
  }

  Future<void> _saveLayoutPanelVisibility() async {
    await _prefs!.setString(
      _keyLayoutPanelVisibility,
      jsonEncode(_layoutPanelVisibility),
    );
  }

  List<String> _loadLayoutOpenEditors() {
    final jsonStr = _prefs!.getString(_keyLayoutOpenEditors);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String>[];
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> _saveLayoutOpenEditors() async {
    await _prefs!.setString(
      _keyLayoutOpenEditors,
      jsonEncode(_layoutOpenEditors),
    );
  }

  Map<String, dynamic> _loadLayoutSnapshot() {
    final jsonStr = _prefs!.getString(_keyLayoutSnapshot);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _saveLayoutSnapshot() async {
    await _prefs!.setString(_keyLayoutSnapshot, jsonEncode(_layoutSnapshot));
  }

  Map<String, String> _loadFileTypeDefaults() {
    final jsonStr = _prefs!.getString(_keyFileTypeDefaults);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, String>{};
      }
      final result = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String) {
          result[_normalizeExtension(key)] = value;
        }
      }
      return result;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveFileTypeDefaults() async {
    await _prefs!.setString(
      _keyFileTypeDefaults,
      jsonEncode(_fileTypeDefaultEditors),
    );
  }

  Map<String, ForgeShortcutKey> _loadShortcutOverrides() {
    final jsonStr = _prefs!.getString(_keyShortcutOverrides);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, ForgeShortcutKey>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, ForgeShortcutKey>{};
      }
      final result = <String, ForgeShortcutKey>{};
      for (final entry in decoded.entries) {
        final actionId = entry.key;
        final value = entry.value;
        if (actionId is String && value is Map) {
          final parsed = _shortcutKeyFromMap(Map<String, dynamic>.from(value));
          if (parsed != null) {
            result[actionId] = parsed;
          }
        }
      }
      return result;
    } catch (_) {
      return <String, ForgeShortcutKey>{};
    }
  }

  Future<void> _saveShortcutOverrides() async {
    final serializable = <String, Map<String, dynamic>>{};
    for (final entry in _shortcutOverrides.entries) {
      serializable[entry.key] = _shortcutKeyToMap(entry.value);
    }
    await _prefs!.setString(_keyShortcutOverrides, jsonEncode(serializable));
  }

  Map<String, ForgeChordKey> _loadChordOverrides() {
    final jsonStr = _prefs!.getString(_keyChordOverrides);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, ForgeChordKey>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return <String, ForgeChordKey>{};
      final result = <String, ForgeChordKey>{};
      for (final entry in decoded.entries) {
        final actionId = entry.key;
        final value = entry.value;
        if (actionId is String && value is Map<String, dynamic>) {
          final first = value['firstKey'];
          final second = value['secondKey'];
          if (first is Map && second is Map) {
            final firstKey =
                _shortcutKeyFromMap(Map<String, dynamic>.from(first));
            final secondKey =
                _shortcutKeyFromMap(Map<String, dynamic>.from(second));
            if (firstKey != null && secondKey != null) {
              result[actionId] =
                  ForgeChordKey(firstKey: firstKey, secondKey: secondKey);
            }
          }
        }
      }
      return result;
    } catch (_) {
      return <String, ForgeChordKey>{};
    }
  }

  Future<void> _saveChordOverrides() async {
    final serializable = <String, Map<String, dynamic>>{};
    for (final entry in _chordOverrides.entries) {
      serializable[entry.key] = {
        'firstKey': _shortcutKeyToMap(entry.value.firstKey),
        'secondKey': _shortcutKeyToMap(entry.value.secondKey),
      };
    }
    await _prefs!.setString(_keyChordOverrides, jsonEncode(serializable));
  }

  Set<String> _loadDeletedBindings() {
    final jsonStr = _prefs!.getString(_keyDeletedBindings);
    if (jsonStr == null || jsonStr.trim().isEmpty) return <String>{};
    try {
      final list = jsonDecode(jsonStr);
      if (list is List) {
        return list.cast<String>().toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> _saveDeletedBindings() async {
    await _prefs!.setString(
      _keyDeletedBindings,
      jsonEncode(_deletedBindings.toList()),
    );
  }

  ThemeMode _loadThemeMode() {
    final str = _prefs!.getString(_keyThemeMode);
    if (str == null) return ThemeMode.dark;
    return ThemeMode.values.firstWhere(
      (m) => m.name == str,
      orElse: () => ThemeMode.dark,
    );
  }

  Map<String, dynamic> _shortcutKeyToMap(ForgeShortcutKey key) {
    return <String, dynamic>{
      'keyId': key.key.keyId,
      'primaryModifier': key.primaryModifier,
      'shift': key.shift,
      'alt': key.alt,
    };
  }

  ForgeShortcutKey? _shortcutKeyFromMap(Map<String, dynamic> map) {
    final keyId = map['keyId'];
    if (keyId is! num) {
      return null;
    }
    final logicalKey = LogicalKeyboardKey.findKeyByKeyId(keyId.toInt());
    if (logicalKey == null) {
      return null;
    }
    return ForgeShortcutKey(
      key: logicalKey,
      primaryModifier: map['primaryModifier'] as bool? ?? false,
      shift: map['shift'] as bool? ?? false,
      alt: map['alt'] as bool? ?? false,
    );
  }

  String _normalizeExtension(String extension) {
    final trimmed = extension.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }

  ForgeTextSettings _textSettingsFromMap(Map<String, dynamic> json) {
    return ForgeTextSettings(
      fontFamily:
          (json['fontFamily'] as String?) ??
          ForgeTextDefaults.defaultFontFamily,
      uiFontFamily: json['uiFontFamily'] as String?,
      fontSize:
          (json['fontSize'] as num?)?.toDouble() ??
          ForgeTextDefaults.defaultFontSize,
      lineHeight:
          (json['lineHeight'] as num?)?.toDouble() ??
          ForgeTextDefaults.defaultLineHeight,
      tabSize:
          (json['tabSize'] as num?)?.toInt() ??
          ForgeTextDefaults.defaultTabSize,
      insertSpaces: json['insertSpaces'] as bool? ?? true,
      showWhitespace: json['showWhitespace'] as bool? ?? false,
      wordWrap: json['wordWrap'] as bool? ?? true,
      showLineNumbers: json['showLineNumbers'] as bool? ?? true,
      highlightCurrentLine: json['highlightCurrentLine'] as bool? ?? true,
      maxUndoHistory:
          (json['maxUndoHistory'] as num?)?.toInt() ??
          ForgeTextDefaults.defaultMaxUndoHistory,
    );
  }

  Map<String, dynamic> _textSettingsToMap(ForgeTextSettings settings) {
    return <String, dynamic>{
      'fontFamily': settings.fontFamily,
      'uiFontFamily': settings.uiFontFamily,
      'fontSize': settings.fontSize,
      'lineHeight': settings.lineHeight,
      'tabSize': settings.tabSize,
      'insertSpaces': settings.insertSpaces,
      'showWhitespace': settings.showWhitespace,
      'wordWrap': settings.wordWrap,
      'showLineNumbers': settings.showLineNumbers,
      'highlightCurrentLine': settings.highlightCurrentLine,
      'maxUndoHistory': settings.maxUndoHistory,
    };
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
      _startupPreferences.recentWorkspaces = list
          .take(_maxRecentWorkspaces)
          .toList();
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

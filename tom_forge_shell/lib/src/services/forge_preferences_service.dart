import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// Service for managing persistent preferences.
///
/// Handles startup preferences, recent workspaces, and configuration settings.
/// The preferences every Forge application keeps whatever its layout (text
/// settings, file type defaults, shortcut overrides, search configuration,
/// external tools) are the kit's [ForgeKitPreferences], which this service
/// extends with the panel shell's own: the layout snapshot, the panel sizes
/// and dimensions, the terminal, the appearance and the startup.
///
/// Every key — the kit's and the shell's — is read and written **only**
/// through the [stateStore] given to the constructor; the default is a
/// [ForgeSharedPreferencesStateStore], under the `forge.*` keys and with the
/// value encodings the service always used (strings, bools, ints and
/// doubles as such, maps and lists as JSON text), so an existing user's
/// preferences load unchanged. With a store given, no shared_preferences
/// call is made.
///
/// The rule of [ForgeKitPreferences] holds for the shell's keys too:
/// [load] is the start's restore, and nothing is written before it has
/// finished (a value set before is kept in memory only and dropped: the
/// restore reads the stored value over it); the setters that store at once
/// (theme mode, high contrast, recent workspaces, ...) and [save] write each
/// key once per microtask, the last value.
class ForgePreferencesService extends ForgeKitPreferences {
  /// A service over [stateStore] (default: shared_preferences).
  ForgePreferencesService({super.stateStore});

  /// The service of [store]: [instance] when [store] is its store, else one
  /// service per store (made on first use and kept), so a shell given its
  /// own store gets the preferences from it.
  static ForgePreferencesService forStore(ForgeStateStore store) {
    if (identical(store, instance.stateStore)) return instance;
    return _byStore[store] ??= ForgePreferencesService(stateStore: store);
  }

  static final Expando<ForgePreferencesService> _byStore = Expando();

  static bool debugEnabled = false;

  static const _keyLastWorkspace = 'forge.startup.lastWorkspacePath';
  static const _keyConfigMode = 'forge.startup.configMode';
  static const _keyRememberSettings = 'forge.startup.rememberSettings';
  static const _keyRecentWorkspaces = 'forge.startup.recentWorkspaces';
  static const _keyMaxRecentWorkspaces = 'forge.startup.maxRecentWorkspaces';
  static const _keyConfigDirectory = 'forge.startup.configDirectory';
  static const _keyLayoutPanelSizes = 'forge.layout.panelSizes';
  static const _keyLayoutPanelVisibility = 'forge.layout.panelVisibility';
  static const _keyLayoutOpenEditors = 'forge.layout.openEditors';
  static const _keyLayoutSnapshot = 'forge.layout.snapshot';
  static const _keyThemeMode = 'forge.appearance.themeMode';
  static const _keyHighContrast = 'forge.appearance.highContrast';
  static const _keyTerminalDefaultShell = 'forge.terminal.defaultShell';
  static const _keyTerminalShellPaths = 'forge.terminal.shellPaths';
  static const _keyTerminalStartFolder = 'forge.terminal.startFolder';
  static const _keyTerminalScrollbackLines = 'forge.terminal.scrollbackLines';
  static const _keyTerminalFontFamily = 'forge.terminal.fontFamily';
  static const _keyTerminalFontSize = 'forge.terminal.fontSize';
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
  static const _keyActionBarActions = 'forge.actionBar.actions';

  /// The path setting of an external tool: `forge.tools.<toolId>.path`.
  static String externalToolPathKey(String toolId) =>
      ForgeKitPreferences.externalToolPathKey(toolId);

  ForgeStartupPreferences _startupPreferences = ForgeStartupPreferences();
  int _maxRecentWorkspaces = 10;
  String? _centralConfigDirectory;
  final Map<String, double> _layoutPanelSizes = <String, double>{};
  final Map<String, bool> _layoutPanelVisibility = <String, bool>{};
  Map<String, dynamic> _layoutSnapshot = <String, dynamic>{};
  List<String> _layoutOpenEditors = <String>[];
  ThemeMode _themeMode = ThemeMode.dark;
  bool _highContrast = false;
  String? _terminalDefaultShell;
  List<String> _terminalShellPaths = <String>[];
  String _terminalStartFolder = 'workspace';
  int _terminalScrollbackLines = 10000;
  String _terminalFontFamily = 'monospace';
  double _terminalFontSize = 14.0;
  double _panelContentMinWidth = 400.0;
  double _leftPanelDefaultWidth = 280.0;
  double _rightPanelDefaultWidth = 280.0;
  double _bottomPanelDefaultHeight = 200.0;
  double _dividerHitTarget = 14.0;
  bool _reduceMotion = false;

  /// Action bar per editor type: editorTypeId → list of action ids.
  /// An empty list means no custom configuration (use defaults).
  final Map<String, List<String>> _actionBarActions = <String, List<String>>{};

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
      persistPreference(_keyThemeMode, value.name);
      notifyListeners();
    }
  }

  /// Whether the shell is drawn in high contrast, in every theme mode
  /// (`forge.appearance.highContrast`). The platform's own high-contrast
  /// setting gives high contrast too, through `MaterialApp`'s
  /// `highContrastTheme`.
  bool get highContrast => _highContrast;

  /// Sets and persists [highContrast].
  set highContrast(bool value) {
    if (_highContrast != value) {
      _highContrast = value;
      persistPreference(_keyHighContrast, value);
      notifyListeners();
    }
  }

  /// Maximum number of recent workspaces to track.
  int get maxRecentWorkspaces => _maxRecentWorkspaces;
  set maxRecentWorkspaces(int value) {
    if (_maxRecentWorkspaces != value) {
      _maxRecentWorkspaces = value;
      persistPreference(_keyMaxRecentWorkspaces, value);
      // Trim the list if needed
      if (_startupPreferences.recentWorkspaces.length > value) {
        _startupPreferences.recentWorkspaces = _startupPreferences
            .recentWorkspaces
            .take(value)
            .toList();
        persistPreference(_keyRecentWorkspaces, _recentWorkspacesJson());
      }
      notifyListeners();
    }
  }

  /// Central config directory (null = use workspace-local .forge/).
  String? get centralConfigDirectory => _centralConfigDirectory;
  set centralConfigDirectory(String? value) {
    if (_centralConfigDirectory != value) {
      _centralConfigDirectory = value;
      persistPreference(_keyConfigDirectory, value);
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

  /// Gets the action bar actions for a specific editor type.
  ///
  /// Returns an empty list if no custom configuration exists.
  List<String> getActionBarActions(String editorTypeId) {
    return List<String>.unmodifiable(
      _actionBarActions[editorTypeId] ?? <String>[],
    );
  }

  /// Sets the action bar actions for a specific editor type.
  void setActionBarActions(String editorTypeId, List<String> actionIds) {
    _actionBarActions[editorTypeId] = List<String>.from(actionIds);
    notifyListeners();
  }

  /// All action bar configurations keyed by editor type id.
  Map<String, List<String>> get actionBarActions =>
      Map<String, List<String>>.unmodifiable(_actionBarActions);

  /// Loads preferences from persistent storage: the start's restore (see
  /// the class).
  @override
  Future<void> load() async {
    try {
      await beginRestore();
      try {
        _startupPreferences = ForgeStartupPreferences(
          lastWorkspacePath: storedString(_keyLastWorkspace),
          lastConfigMode: storedString(_keyConfigMode),
          rememberSettings: storedBool(_keyRememberSettings) ?? true,
          recentWorkspaces: _loadRecentWorkspaces(),
        );

        _maxRecentWorkspaces = storedInt(_keyMaxRecentWorkspaces) ?? 10;
        loadKitPreferences();
        _centralConfigDirectory = storedString(_keyConfigDirectory);
        _layoutPanelSizes
          ..clear()
          ..addAll(_loadLayoutPanelSizes());
        _layoutPanelVisibility
          ..clear()
          ..addAll(_loadLayoutPanelVisibility());
        _layoutSnapshot = _loadLayoutSnapshot();
        _layoutOpenEditors = _loadLayoutOpenEditors();
        _themeMode = _loadThemeMode();
        _highContrast = storedBool(_keyHighContrast) ?? false;
        _terminalDefaultShell = storedString(_keyTerminalDefaultShell);
        _terminalShellPaths = _loadTerminalShellPaths();
        _terminalStartFolder =
            storedString(_keyTerminalStartFolder) ?? 'workspace';
        _terminalScrollbackLines =
            storedInt(_keyTerminalScrollbackLines) ?? 10000;
        _terminalFontFamily =
            storedString(_keyTerminalFontFamily) ?? 'monospace';
        _terminalFontSize = storedDouble(_keyTerminalFontSize) ?? 14.0;
        _panelContentMinWidth =
            storedDouble(_keyDimPanelContentMinWidth) ?? 400.0;
        _leftPanelDefaultWidth =
            storedDouble(_keyDimLeftPanelDefaultWidth) ?? 280.0;
        _rightPanelDefaultWidth =
            storedDouble(_keyDimRightPanelDefaultWidth) ?? 280.0;
        _bottomPanelDefaultHeight =
            storedDouble(_keyDimBottomPanelDefaultHeight) ?? 200.0;
        _dividerHitTarget = storedDouble(_keyDimDividerHitTarget) ?? 14.0;
        _reduceMotion = storedBool(_keyReduceMotion) ?? false;
        _loadActionBarActions();
      } finally {
        finishRestore();
      }
      _isLoaded = true;
      _log(
        'loaded preferences with ${editorTextSettings.length} editor settings entries',
      );

      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('[ForgePreferencesService] load failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  List<String> _loadRecentWorkspaces() {
    final jsonStr = storedJson(_keyRecentWorkspaces);
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

  /// Saves all preferences to persistent storage, each key once.
  @override
  Future<void> save() async {
    try {
      if (!_isLoaded) {
        await load();
      }

      await Future.wait([
        writePreference(
          _keyLastWorkspace,
          _startupPreferences.lastWorkspacePath,
        ),
        writePreference(_keyConfigMode, _startupPreferences.lastConfigMode),
        writePreference(
          _keyRememberSettings,
          _startupPreferences.rememberSettings,
        ),
        _saveRecentWorkspaces(),
        saveKitPreferences(),
        _saveLayoutPanelSizes(),
        _saveLayoutPanelVisibility(),
        _saveLayoutOpenEditors(),
        _saveLayoutSnapshot(),
        writePreference(_keyThemeMode, _themeMode.name),
        writePreference(_keyHighContrast, _highContrast),
        _saveTerminalPreferences(),
        _saveLayoutDimensions(),
      ]);
      _log(
        'saved preferences with ${editorTextSettings.length} editor settings entries',
      );
    } catch (error, stackTrace) {
      debugPrint('[ForgePreferencesService] save failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  String _recentWorkspacesJson() =>
      jsonEncode(_startupPreferences.recentWorkspaces);

  Future<void> _saveRecentWorkspaces() =>
      writePreference(_keyRecentWorkspaces, _recentWorkspacesJson());

  List<String> _loadTerminalShellPaths() {
    final jsonStr = storedJson(_keyTerminalShellPaths);
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

  Future<void> _saveTerminalPreferences() => Future.wait([
    writePreference(_keyTerminalDefaultShell, _terminalDefaultShell),
    writePreference(_keyTerminalShellPaths, jsonEncode(_terminalShellPaths)),
    writePreference(_keyTerminalStartFolder, _terminalStartFolder),
    writePreference(_keyTerminalScrollbackLines, _terminalScrollbackLines),
    writePreference(_keyTerminalFontFamily, _terminalFontFamily),
    writePreference(_keyTerminalFontSize, _terminalFontSize),
  ]);

  Future<void> _saveLayoutDimensions() => Future.wait([
    writePreference(_keyDimPanelContentMinWidth, _panelContentMinWidth),
    writePreference(_keyDimLeftPanelDefaultWidth, _leftPanelDefaultWidth),
    writePreference(_keyDimRightPanelDefaultWidth, _rightPanelDefaultWidth),
    writePreference(_keyDimBottomPanelDefaultHeight, _bottomPanelDefaultHeight),
    writePreference(_keyDimDividerHitTarget, _dividerHitTarget),
    writePreference(_keyReduceMotion, _reduceMotion),
    _saveActionBarActions(),
  ]);

  void _loadActionBarActions() {
    final jsonStr = storedJson(_keyActionBarActions);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        _actionBarActions.clear();
        for (final entry in decoded.entries) {
          if (entry.key is String && entry.value is List) {
            _actionBarActions[entry.key as String] = (entry.value as List)
                .cast<String>();
          }
        }
      }
    } catch (e) {
      _log('failed to load action bar actions: $e');
    }
  }

  Future<void> _saveActionBarActions() =>
      writePreference(_keyActionBarActions, jsonEncode(_actionBarActions));

  Map<String, double> _loadLayoutPanelSizes() {
    final jsonStr = storedJson(_keyLayoutPanelSizes);
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

  Future<void> _saveLayoutPanelSizes() =>
      writePreference(_keyLayoutPanelSizes, jsonEncode(_layoutPanelSizes));

  Map<String, bool> _loadLayoutPanelVisibility() {
    final jsonStr = storedJson(_keyLayoutPanelVisibility);
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

  Future<void> _saveLayoutPanelVisibility() => writePreference(
    _keyLayoutPanelVisibility,
    jsonEncode(_layoutPanelVisibility),
  );

  List<String> _loadLayoutOpenEditors() {
    final jsonStr = storedJson(_keyLayoutOpenEditors);
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

  Future<void> _saveLayoutOpenEditors() =>
      writePreference(_keyLayoutOpenEditors, jsonEncode(_layoutOpenEditors));

  Map<String, dynamic> _loadLayoutSnapshot() {
    final jsonStr = storedJson(_keyLayoutSnapshot);
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

  Future<void> _saveLayoutSnapshot() =>
      writePreference(_keyLayoutSnapshot, jsonEncode(_layoutSnapshot));

  ThemeMode _loadThemeMode() {
    final str = storedString(_keyThemeMode);
    if (str == null) return ThemeMode.dark;
    return ThemeMode.values.firstWhere(
      (m) => m.name == str,
      orElse: () => ThemeMode.dark,
    );
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

    await Future.wait([
      _saveRecentWorkspaces(),
      writePreference(_keyLastWorkspace, path),
    ]);
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
    await Future.wait([
      _saveRecentWorkspaces(),
      writePreference(_keyLastWorkspace, null),
    ]);
    notifyListeners();
  }

  /// Writes the current value of the appearance, startup, layout-dimension
  /// or terminal preference [key] (a `forge.*` key of this service, e.g.
  /// `forge.terminal.fontSize`) as [save] writes it — only that key. The
  /// shell's configuration description stores its settings so
  /// (`ForgePreferencesSettingBinding`). A key this service does not know
  /// writes nothing.
  Future<void> saveKey(String key) {
    final Object? value = switch (key) {
      _keyThemeMode => _themeMode.name,
      _keyHighContrast => _highContrast,
      _keyReduceMotion => _reduceMotion,
      _keyMaxRecentWorkspaces => _maxRecentWorkspaces,
      _keyTerminalDefaultShell => _terminalDefaultShell,
      _keyTerminalShellPaths => jsonEncode(_terminalShellPaths),
      _keyTerminalStartFolder => _terminalStartFolder,
      _keyTerminalScrollbackLines => _terminalScrollbackLines,
      _keyTerminalFontFamily => _terminalFontFamily,
      _keyTerminalFontSize => _terminalFontSize,
      _keyDimPanelContentMinWidth => _panelContentMinWidth,
      _keyDimLeftPanelDefaultWidth => _leftPanelDefaultWidth,
      _keyDimRightPanelDefaultWidth => _rightPanelDefaultWidth,
      _keyDimBottomPanelDefaultHeight => _bottomPanelDefaultHeight,
      _keyDimDividerHitTarget => _dividerHitTarget,
      'forge.search.config' => jsonEncode(searchConfig.toJson()),
      _ => _unknownKey,
    };
    if (identical(value, _unknownKey)) return Future.value();
    return writePreference(key, value);
  }

  static const Object _unknownKey = Object();

  /// Creates a singleton instance with default settings.
  static final ForgePreferencesService instance = ForgePreferencesService();
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:tom_forge_core/tom_forge_core.dart';

import '../services/forge_preferences_service.dart';

/// The [ForgeSettingBinding] of the shell's own preferences: the settings of
/// the shell's configuration description (`forgeShellConfiguration`) read
/// and write their documents through the [ForgePreferencesService], under
/// the keys and in the encodings the service always used, so an existing
/// user's preferences are read unchanged.
///
/// Going through the service, not around it, keeps its values current —
/// a later [ForgePreferencesService.save] writes no stale value back — and
/// keeps what follows a change: the service notifies, and its listeners
/// apply the theme, high contrast and reduce motion, hand the search
/// configuration to the search view and the layout dimensions to the
/// panels.
///
/// A document is the key's value as JSON: the theme mode's name, a bool, an
/// int, a double, a string, the shell paths as a list, and the search
/// configuration as the map of `ForgeSearchConfig.toJson` (the search
/// settings reach into it with their paths). Null (a reset) puts the
/// service's default back. [watch] reports the keys whose documents changed
/// whenever the service notifies because someone else changed a preference
/// (not for this binding's own writes).
class ForgePreferencesSettingBinding extends ForgeSettingBinding {
  ForgePreferencesSettingBinding(this.preferences);

  /// The binding's id, which the shell's settings name in their storage.
  static const bindingId = 'forge.preferences';

  /// `forge.appearance.themeMode`: `dark`, `light` or `system`.
  static const themeModeKey = 'forge.appearance.themeMode';

  /// `forge.appearance.highContrast`.
  static const highContrastKey = 'forge.appearance.highContrast';

  /// `forge.appearance.reduceMotion`.
  static const reduceMotionKey = 'forge.appearance.reduceMotion';

  /// `forge.startup.maxRecentWorkspaces`.
  static const maxRecentWorkspacesKey = 'forge.startup.maxRecentWorkspaces';

  /// `forge.search.config`: the map of `ForgeSearchConfig.toJson`.
  static const searchConfigKey = 'forge.search.config';

  /// `forge.layout.dim.panelContentMinWidth`.
  static const panelContentMinWidthKey =
      'forge.layout.dim.panelContentMinWidth';

  /// `forge.layout.dim.leftPanelDefaultWidth`.
  static const leftPanelDefaultWidthKey =
      'forge.layout.dim.leftPanelDefaultWidth';

  /// `forge.layout.dim.rightPanelDefaultWidth`.
  static const rightPanelDefaultWidthKey =
      'forge.layout.dim.rightPanelDefaultWidth';

  /// `forge.layout.dim.bottomPanelDefaultHeight`.
  static const bottomPanelDefaultHeightKey =
      'forge.layout.dim.bottomPanelDefaultHeight';

  /// `forge.layout.dim.dividerHitTarget`.
  static const dividerHitTargetKey = 'forge.layout.dim.dividerHitTarget';

  /// `forge.terminal.defaultShell`: a path, absent for the platform's.
  static const terminalDefaultShellKey = 'forge.terminal.defaultShell';

  /// `forge.terminal.shellPaths`: the shells offered, a list of paths.
  static const terminalShellPathsKey = 'forge.terminal.shellPaths';

  /// `forge.terminal.startFolder`: `workspace`, `home` or `lastUsed`.
  static const terminalStartFolderKey = 'forge.terminal.startFolder';

  /// `forge.terminal.scrollbackLines`.
  static const terminalScrollbackLinesKey = 'forge.terminal.scrollbackLines';

  /// `forge.terminal.fontFamily`.
  static const terminalFontFamilyKey = 'forge.terminal.fontFamily';

  /// `forge.terminal.fontSize`.
  static const terminalFontSizeKey = 'forge.terminal.fontSize';

  /// The service the documents are read from and written to.
  final ForgePreferencesService preferences;

  StreamController<String>? _changes;

  /// The keys this binding keeps.
  static const keys = [
    themeModeKey,
    highContrastKey,
    reduceMotionKey,
    maxRecentWorkspacesKey,
    searchConfigKey,
    panelContentMinWidthKey,
    leftPanelDefaultWidthKey,
    rightPanelDefaultWidthKey,
    bottomPanelDefaultHeightKey,
    dividerHitTargetKey,
    terminalDefaultShellKey,
    terminalShellPathsKey,
    terminalStartFolderKey,
    terminalScrollbackLinesKey,
    terminalFontFamilyKey,
    terminalFontSizeKey,
  ];

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async => _documentOf(key);

  Object? _documentOf(String key) {
    final p = preferences;
    return switch (key) {
      themeModeKey => p.themeMode.name,
      highContrastKey => p.highContrast,
      reduceMotionKey => p.reduceMotion,
      maxRecentWorkspacesKey => p.maxRecentWorkspaces,
      searchConfigKey => p.searchConfig.toJson(),
      panelContentMinWidthKey => p.panelContentMinWidth,
      leftPanelDefaultWidthKey => p.leftPanelDefaultWidth,
      rightPanelDefaultWidthKey => p.rightPanelDefaultWidth,
      bottomPanelDefaultHeightKey => p.bottomPanelDefaultHeight,
      dividerHitTargetKey => p.dividerHitTarget,
      terminalDefaultShellKey => p.terminalDefaultShell,
      terminalShellPathsKey => p.terminalShellPaths,
      terminalStartFolderKey => p.terminalStartFolder,
      terminalScrollbackLinesKey => p.terminalScrollbackLines,
      terminalFontFamilyKey => p.terminalFontFamily,
      terminalFontSizeKey => p.terminalFontSize,
      _ => null,
    };
  }

  @override
  Future<void> write(String key, Object? document) {
    // The service notifies while its value is set; the values service
    // knows this change already, so it is not reported back ([watch]):
    // reading it again could race a following write of the same document.
    _writing++;
    try {
      return _write(key, document);
    } finally {
      _writing--;
      if (keys.contains(key)) _reported[key] = _encoded(key);
    }
  }

  int _writing = 0;

  Future<void> _write(String key, Object? document) {
    final p = preferences;
    switch (key) {
      case themeModeKey:
        // The setter stores the key itself.
        p.themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == document,
          orElse: () => ThemeMode.dark,
        );
        return p.flushed();
      case highContrastKey:
        p.highContrast = document is bool && document;
        return p.flushed();
      case maxRecentWorkspacesKey:
        p.maxRecentWorkspaces = document is num ? document.toInt() : 10;
        return p.flushed();
      case searchConfigKey:
        // A setting reset removes its field: the default fills it again.
        p.searchConfig = ForgeSearchConfig.fromJson({
          ...const ForgeSearchConfig().toJson(),
          if (document is Map)
            for (final entry in document.entries) '${entry.key}': entry.value,
        });
        return p.flushed();
      case reduceMotionKey:
        p.reduceMotion = document is bool && document;
      case panelContentMinWidthKey:
        p.panelContentMinWidth = _double(document, 400);
      case leftPanelDefaultWidthKey:
        p.leftPanelDefaultWidth = _double(document, 280);
      case rightPanelDefaultWidthKey:
        p.rightPanelDefaultWidth = _double(document, 280);
      case bottomPanelDefaultHeightKey:
        p.bottomPanelDefaultHeight = _double(document, 200);
      case dividerHitTargetKey:
        p.dividerHitTarget = _double(document, 14);
      case terminalDefaultShellKey:
        final shell = document is String ? document.trim() : '';
        p.terminalDefaultShell = shell.isEmpty ? null : shell;
      case terminalShellPathsKey:
        p.terminalShellPaths = document is List
            ? [for (final item in document) '$item']
            : const [];
      case terminalStartFolderKey:
        p.terminalStartFolder = document is String ? document : 'workspace';
      case terminalScrollbackLinesKey:
        p.terminalScrollbackLines = document is num ? document.toInt() : 10000;
      case terminalFontFamilyKey:
        final family = document is String ? document.trim() : '';
        p.terminalFontFamily = family.isEmpty ? 'monospace' : family;
      case terminalFontSizeKey:
        p.terminalFontSize = _double(document, 14);
      default:
        return Future.value();
    }
    // These setters keep the value in memory only; store this key.
    return p.saveKey(key);
  }

  static double _double(Object? document, double fallback) =>
      document is num ? document.toDouble() : fallback;

  @override
  Stream<String> watch() {
    final changes = _changes ??= StreamController<String>.broadcast(
      onListen: () {
        for (final key in keys) {
          _reported[key] = _encoded(key);
        }
        preferences.addListener(_onPreferencesChanged);
      },
      onCancel: () => preferences.removeListener(_onPreferencesChanged),
    );
    return changes.stream;
  }

  /// The documents as last reported, JSON-encoded, by key.
  final Map<String, String> _reported = {};

  String _encoded(String key) => jsonEncode(_documentOf(key));

  void _onPreferencesChanged() {
    final changes = _changes;
    if (changes == null || !changes.hasListener || _writing > 0) return;
    for (final key in keys) {
      final now = _encoded(key);
      if (_reported[key] == now) continue;
      _reported[key] = now;
      changes.add(key);
    }
  }

  @override
  Future<void> flushed() => preferences.flushed();
}

/// The [ForgeSettingBinding] of the shell's auto-save configuration
/// (`ForgeConfig.autoSave`), which lives in the [ForgeConfigManager] — a
/// [DefaultConfigManager] — for the session, as it always did.
///
/// One document, [autoSaveKey]: `{enabled, idleDelaySeconds,
/// saveOnFocusLoss}`. A write replaces the manager's configuration with the
/// auto-save changed (`DefaultConfigManager.setCurrent`, key `autoSave`),
/// which the shell's auto-save follows; a manager of another kind cannot be
/// changed and the write is dropped. [watch] reports the document whenever
/// the manager announces a change.
class ForgeConfigSettingBinding extends ForgeSettingBinding {
  const ForgeConfigSettingBinding(this.config);

  /// The binding's id, which the auto-save settings name in their storage.
  static const bindingId = 'forge.config';

  /// The auto-save document.
  static const autoSaveKey = 'autoSave';

  /// The manager the configuration is read from and written to.
  final ForgeConfigManager config;

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async {
    if (key != autoSaveKey) return null;
    final autoSave = config.current.autoSave;
    return {
      'enabled': autoSave.enabled,
      'idleDelaySeconds': autoSave.idleDelay.inSeconds,
      'saveOnFocusLoss': autoSave.saveOnFocusLoss,
    };
  }

  @override
  Future<void> write(String key, Object? document) async {
    final manager = config;
    if (key != autoSaveKey || manager is! DefaultConfigManager) return;
    const defaults = AutoSaveConfig();
    final map = document is Map ? document : const {};
    final enabled = map['enabled'];
    final delay = map['idleDelaySeconds'];
    final focusLoss = map['saveOnFocusLoss'];
    final current = manager.current;
    manager.setCurrent(
      ForgeConfig(
        autoSave: AutoSaveConfig(
          enabled: enabled is bool ? enabled : defaults.enabled,
          idleDelay: delay is num && delay > 0
              ? Duration(seconds: delay.toInt())
              : defaults.idleDelay,
          saveOnFocusLoss: focusLoss is bool
              ? focusLoss
              : defaults.saveOnFocusLoss,
        ),
        performance: current.performance,
      ),
      key: autoSaveKey,
    );
  }

  @override
  Stream<String> watch() => config.onDidChange
      .where((event) => event.key == autoSaveKey || event.key.isEmpty)
      .map((_) => autoSaveKey);
}

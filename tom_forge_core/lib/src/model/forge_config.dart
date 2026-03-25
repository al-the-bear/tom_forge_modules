/// Auto-save configuration.
class AutoSaveConfig {
  final bool enabled;
  final Duration idleDelay;
  final bool saveOnFocusLoss;

  const AutoSaveConfig({
    this.enabled = true,
    this.idleDelay = const Duration(seconds: 1),
    this.saveOnFocusLoss = true,
  });
}

/// Top-level forge configuration.
class ForgeConfig {
  final AutoSaveConfig autoSave;

  const ForgeConfig({
    this.autoSave = const AutoSaveConfig(),
  });
}

/// Startup preferences (persisted across sessions).
class ForgeStartupPreferences {
  String? lastWorkspacePath;
  String? lastConfigMode;
  bool rememberSettings;
  List<String> recentWorkspaces;

  ForgeStartupPreferences({
    this.lastWorkspacePath,
    this.lastConfigMode,
    this.rememberSettings = true,
    List<String>? recentWorkspaces,
  }) : recentWorkspaces = recentWorkspaces ?? [];
}

import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../defaults/default_shell_api.dart';
import '../services/forge_preferences_service.dart';
import 'forge_shell_setting_bindings.dart';
import 'forge_files_tools_configuration.dart';
import 'forge_shortcut_configuration.dart';

/// The shell's own options as a configuration description: the *Shell*
/// section (appearance, quick access, auto save, search, layout) and the
/// *Terminal* section (default shell, start folder, font and display).
///
/// Every setting keeps the key and the encoding the shell always used: the
/// preferences through [ForgePreferencesSettingBinding] (`forge.preferences`,
/// the `forge.*` keys of `ForgePreferencesService`), the auto-save through
/// [ForgeConfigSettingBinding] (`forge.config`, `ForgeConfig.autoSave`). The
/// shell contributes them with [ForgeShellConfigurationModule], which the
/// scaffold registers; the scaffold supplies the two bindings to its values
/// service ([forgeShellSettingBindings]).
abstract final class ForgeShellConfiguration {
  /// The description's id.
  static const descriptionId = 'forge.shell';

  /// The id of the *Shell* section.
  static const shellSectionId = 'shell';

  /// The id of the *Terminal* section.
  static const terminalSectionId = 'terminal';

  /// `<description>/<section>` of the *Shell* section
  /// (`ForgeConfigurationSectionRef.id`).
  static const shellSectionRef = '$descriptionId/$shellSectionId';

  /// `<description>/<section>` of the *Terminal* section.
  static const terminalSectionRef = '$descriptionId/$terminalSectionId';

  /// The id of the choices provider listing the terminal's fonts.
  static const terminalFontsProvider = 'forge.shell.terminalFonts';

  static const _prefs = ForgePreferencesSettingBinding.bindingId;

  static ForgeText _label(String section, String setting, String text) =>
      ForgeText('forge.config.$section.$setting.label', text);

  // ── Shell: appearance ──

  /// The theme: dark, light or the platform's.
  static final themeMode = ForgeChoiceSetting(
    id: 'themeMode',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.themeModeKey,
      binding: _prefs,
    ),
    label: _label('shell', 'themeMode', 'Theme'),
    defaultValue: 'dark',
    choices: const [
      ForgeSettingChoice(
        'dark',
        ForgeText('forge.config.shell.themeMode.dark', 'Dark'),
      ),
      ForgeSettingChoice(
        'light',
        ForgeText('forge.config.shell.themeMode.light', 'Light'),
      ),
      ForgeSettingChoice(
        'system',
        ForgeText('forge.config.shell.themeMode.system', 'System'),
      ),
    ],
    display: ForgeChoiceDisplay.segmented,
  );

  /// High contrast in every theme mode.
  static final highContrast = ForgeBoolSetting(
    id: 'highContrast',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.highContrastKey,
      binding: _prefs,
    ),
    label: _label('shell', 'highContrast', 'High contrast'),
  );

  // ── Shell: quick access ──

  /// How many recent workspaces are kept (1–50).
  static final maxRecentWorkspaces = ForgeIntSetting(
    id: 'maxRecentWorkspaces',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.maxRecentWorkspacesKey,
      binding: _prefs,
    ),
    label: _label('shell', 'maxRecentWorkspaces', 'Max recent'),
    defaultValue: 10,
    min: 1,
    max: 50,
  );

  // ── Shell: auto save ──

  static const _autoSave = ForgeConfigSettingBinding.bindingId;
  static const _autoSaveKey = ForgeConfigSettingBinding.autoSaveKey;

  /// Whether dirty editors are saved when idle.
  static final autoSaveEnabled = ForgeBoolSetting(
    id: 'autoSaveEnabled',
    storage: const ForgeSettingStorage(
      _autoSaveKey,
      path: ['enabled'],
      binding: _autoSave,
    ),
    label: _label('shell', 'autoSaveEnabled', 'Enabled'),
    defaultValue: true,
  );

  /// Whether dirty editors are saved when the window loses focus.
  static final autoSaveOnFocusLoss = ForgeBoolSetting(
    id: 'autoSaveOnFocusLoss',
    storage: const ForgeSettingStorage(
      _autoSaveKey,
      path: ['saveOnFocusLoss'],
      binding: _autoSave,
    ),
    label: _label('shell', 'autoSaveOnFocusLoss', 'Save on focus loss'),
    defaultValue: true,
  );

  /// The idle time before an auto save, in seconds.
  static final autoSaveIdleDelay = ForgeIntSetting(
    id: 'autoSaveIdleDelay',
    storage: const ForgeSettingStorage(
      _autoSaveKey,
      path: ['idleDelaySeconds'],
      binding: _autoSave,
    ),
    label: _label('shell', 'autoSaveIdleDelay', 'Idle delay'),
    defaultValue: 2,
    min: 1,
    unit: const ForgeText('forge.config.unit.seconds', 's'),
  );

  // ── Shell: search ──

  static const _search = ForgePreferencesSettingBinding.searchConfigKey;

  /// Whether hidden directories are left out of searches.
  static final searchHideHiddenDirectories = ForgeBoolSetting(
    id: 'searchHideHiddenDirectories',
    storage: const ForgeSettingStorage(
      _search,
      path: ['excludeHiddenDirectories'],
      binding: _prefs,
    ),
    label: _label('shell', 'searchHideHiddenDirectories', 'Hide hidden dirs'),
    defaultValue: true,
  );

  /// Whether the `.gitignore` files are followed in searches.
  static final searchUseGitIgnore = ForgeBoolSetting(
    id: 'searchUseGitIgnore',
    storage: const ForgeSettingStorage(
      _search,
      path: ['excludeGitIgnored'],
      binding: _prefs,
    ),
    label: _label('shell', 'searchUseGitIgnore', 'Use .gitignore'),
    defaultValue: true,
  );

  /// The file extensions searches skip.
  static final searchExcludedExtensions = ForgeStringListSetting(
    id: 'searchExcludedExtensions',
    storage: const ForgeSettingStorage(
      _search,
      path: ['excludedExtensions'],
      binding: _prefs,
    ),
    label: _label('shell', 'searchExcludedExtensions', 'Excluded extensions'),
    // ForgeSearchConfig's defaults, sorted as it stores them.
    defaultValue: const [
      '7z', 'a', 'aot', 'avi', 'bmp', 'bz2', 'class', 'dill', 'dll', //
      'dylib', 'exe', 'g.dart', 'gif', 'gz', 'ico', 'jpeg', 'jpg', 'lock',
      'mov', 'mp3', 'mp4', 'o', 'png', 'pyc', 'rar', 'so', 'svg', 'tar',
      'wav', 'webp', 'xz', 'zip',
    ],
    hint: const ForgeText(
      'forge.config.shell.searchExcludedExtensions.hint',
      'png, jpg, exe, lock',
    ),
  );

  /// The directory names searches skip.
  static final searchExcludedDirectories = ForgeStringListSetting(
    id: 'searchExcludedDirectories',
    storage: const ForgeSettingStorage(
      _search,
      path: ['excludedDirectories'],
      binding: _prefs,
    ),
    label: _label('shell', 'searchExcludedDirectories', 'Excluded directories'),
    defaultValue: const [
      '.dart_tool', '.git', '.idea', '.vscode', '__pycache__', 'build', //
      'node_modules',
    ],
    hint: const ForgeText(
      'forge.config.shell.searchExcludedDirectories.hint',
      'node_modules, build, .dart_tool',
    ),
  );

  /// The largest file searched, stored in bytes and shown in MB.
  static final searchFileSizeLimit = ForgeIntSetting(
    id: 'searchFileSizeLimit',
    storage: const ForgeSettingStorage(
      _search,
      path: ['fileSizeLimit'],
      binding: _prefs,
    ),
    label: _label('shell', 'searchFileSizeLimit', 'Size'),
    defaultValue: 10 * 1024 * 1024,
    min: 1024 * 1024,
    scale: 1024 * 1024,
    unit: const ForgeText('forge.config.unit.megabytes', 'MB'),
  );

  /// The most files a search lists (1–1000).
  static final searchMaxFileResults = ForgeIntSetting(
    id: 'searchMaxFileResults',
    storage: const ForgeSettingStorage(
      _search,
      path: ['maxFileResults'],
      binding: _prefs,
    ),
    label: _label('shell', 'searchMaxFileResults', 'Max results'),
    defaultValue: 50,
    min: 1,
    max: 1000,
  );

  // ── Shell: layout ──

  /// Whether the shell's animations are switched off.
  static final reduceMotion = ForgeBoolSetting(
    id: 'reduceMotion',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.reduceMotionKey,
      binding: _prefs,
    ),
    label: _label('shell', 'reduceMotion', 'Reduce motion'),
  );

  static ForgeDoubleSetting _dimension({
    required String id,
    required String key,
    required String text,
    required double defaultValue,
    required double min,
    required double max,
  }) => ForgeDoubleSetting(
    id: id,
    storage: ForgeSettingStorage(key, binding: _prefs),
    label: _label('shell', id, text),
    defaultValue: defaultValue,
    min: min,
    max: max,
    decimals: 0,
    unit: const ForgeText('forge.config.unit.pixels', 'px'),
  );

  /// The narrowest a side panel's content is laid out (100–2000).
  static final panelContentMinWidth = _dimension(
    id: 'panelContentMinWidth',
    key: ForgePreferencesSettingBinding.panelContentMinWidthKey,
    text: 'Panel min width',
    defaultValue: 400,
    min: 100,
    max: 2000,
  );

  /// The left panel's width at first (100–800).
  static final leftPanelDefaultWidth = _dimension(
    id: 'leftPanelDefaultWidth',
    key: ForgePreferencesSettingBinding.leftPanelDefaultWidthKey,
    text: 'Left panel',
    defaultValue: 280,
    min: 100,
    max: 800,
  );

  /// The right panel's width at first (100–800).
  static final rightPanelDefaultWidth = _dimension(
    id: 'rightPanelDefaultWidth',
    key: ForgePreferencesSettingBinding.rightPanelDefaultWidthKey,
    text: 'Right panel',
    defaultValue: 280,
    min: 100,
    max: 800,
  );

  /// The bottom panel's height at first (50–600).
  static final bottomPanelDefaultHeight = _dimension(
    id: 'bottomPanelDefaultHeight',
    key: ForgePreferencesSettingBinding.bottomPanelDefaultHeightKey,
    text: 'Bottom panel',
    defaultValue: 200,
    min: 50,
    max: 600,
  );

  /// How wide a panel divider reacts to the pointer (4–40).
  static final dividerHitTarget = _dimension(
    id: 'dividerHitTarget',
    key: ForgePreferencesSettingBinding.dividerHitTargetKey,
    text: 'Divider hit',
    defaultValue: 14,
    min: 4,
    max: 40,
  );

  // ── Terminal ──

  /// The shell a new terminal runs; empty: the platform's.
  static final terminalDefaultShell = ForgePathSetting(
    id: 'defaultShell',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.terminalDefaultShellKey,
      binding: _prefs,
    ),
    label: _label('terminal', 'defaultShell', 'Default Shell'),
    hint: const ForgeText(
      'forge.config.terminal.defaultShell.hint',
      '/bin/bash',
    ),
  );

  /// The shells offered for a new terminal.
  static final terminalShellPaths = ForgeStringListSetting(
    id: 'shellPaths',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.terminalShellPathsKey,
      binding: _prefs,
    ),
    label: _label('terminal', 'shellPaths', 'Shell paths'),
    hint: const ForgeText(
      'forge.config.terminal.shellPaths.hint',
      '/bin/zsh, /bin/bash',
    ),
  );

  /// Where a new terminal starts.
  static final terminalStartFolder = ForgeChoiceSetting(
    id: 'startFolder',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.terminalStartFolderKey,
      binding: _prefs,
    ),
    label: _label('terminal', 'startFolder', 'Start Folder'),
    defaultValue: 'workspace',
    choices: const [
      ForgeSettingChoice(
        'workspace',
        ForgeText(
          'forge.config.terminal.startFolder.workspace',
          'Workspace root',
        ),
      ),
      ForgeSettingChoice(
        'home',
        ForgeText('forge.config.terminal.startFolder.home', 'Home directory'),
      ),
      ForgeSettingChoice(
        'lastUsed',
        ForgeText(
          'forge.config.terminal.startFolder.lastUsed',
          'Last used directory',
        ),
      ),
    ],
    display: ForgeChoiceDisplay.dropdown,
  );

  /// The terminal's font.
  static final terminalFontFamily = ForgeFontFamilySetting(
    id: 'fontFamily',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.terminalFontFamilyKey,
      binding: _prefs,
    ),
    label: _label('terminal', 'fontFamily', 'Font'),
    defaultValue: 'monospace',
    monospace: true,
    fontsProvider: terminalFontsProvider,
    allowEmpty: false,
  );

  /// The terminal's font size.
  static final terminalFontSize = ForgeDoubleSetting(
    id: 'fontSize',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.terminalFontSizeKey,
      binding: _prefs,
    ),
    label: _label('terminal', 'fontSize', 'Size'),
    defaultValue: 14,
    min: 1,
    max: 200,
    decimals: 0,
  );

  /// The lines a terminal keeps to scroll back to.
  static final terminalScrollbackLines = ForgeIntSetting(
    id: 'scrollbackLines',
    storage: const ForgeSettingStorage(
      ForgePreferencesSettingBinding.terminalScrollbackLinesKey,
      binding: _prefs,
    ),
    label: _label('terminal', 'scrollbackLines', 'Scrollback'),
    defaultValue: 10000,
    min: 1,
  );

  /// The *Shell* section.
  static final shellSection = ForgeSettingsSection(
    id: shellSectionId,
    title: const ForgeText('forge.config.shell.title', 'Shell'),
    icon: ForgeIconRef(Icons.desktop_mac_outlined.codePoint),
    order: 0,
    settings: [
      ForgeSettingsGroup(
        id: 'appearance',
        title: const ForgeText('forge.config.shell.appearance', 'Appearance'),
        settings: [themeMode, highContrast],
      ),
      ForgeSettingsGroup(
        id: 'quickAccess',
        title: const ForgeText(
          'forge.config.shell.quickAccess',
          'Quick Access',
        ),
        settings: [maxRecentWorkspaces],
      ),
      ForgeSettingsGroup(
        id: 'autoSave',
        title: const ForgeText('forge.config.shell.autoSave', 'Auto Save'),
        settings: [autoSaveEnabled, autoSaveOnFocusLoss, autoSaveIdleDelay],
      ),
      ForgeSettingsGroup(
        id: 'search',
        title: const ForgeText('forge.config.shell.search', 'Search'),
        settings: [
          searchHideHiddenDirectories,
          searchUseGitIgnore,
          searchExcludedExtensions,
          searchExcludedDirectories,
          searchFileSizeLimit,
          searchMaxFileResults,
        ],
      ),
      ForgeSettingsGroup(
        id: 'layout',
        title: const ForgeText('forge.config.shell.layout', 'Layout'),
        settings: [
          reduceMotion,
          panelContentMinWidth,
          leftPanelDefaultWidth,
          rightPanelDefaultWidth,
          bottomPanelDefaultHeight,
          dividerHitTarget,
        ],
      ),
    ],
  );

  /// The *Terminal* section.
  static final terminalSection = ForgeSettingsSection(
    id: terminalSectionId,
    title: const ForgeText('forge.config.terminal.title', 'Terminal'),
    icon: ForgeIconRef(Icons.terminal.codePoint),
    order: 1,
    settings: [
      terminalDefaultShell,
      terminalShellPaths,
      terminalStartFolder,
      ForgeSettingsGroup(
        id: 'fontAndDisplay',
        title: const ForgeText(
          'forge.config.terminal.fontAndDisplay',
          'Font & Display',
        ),
        settings: [
          terminalFontFamily,
          terminalFontSize,
          terminalScrollbackLines,
        ],
      ),
    ],
  );

  /// The description: [shellSection] and [terminalSection].
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: const ForgeText('forge.config.shell.description', 'Shell'),
    sections: [shellSection, terminalSection],
  );

  /// Fonts offered for the terminal when nothing better is known: Flutter
  /// cannot list the system's fonts, so these are the usual fixed-width
  /// fonts of the desktop platforms; any other name may be typed.
  static const terminalFonts = [
    'monospace',
    'Menlo',
    'Monaco',
    'SF Mono',
    'Courier New',
    'Consolas',
    'Cascadia Code',
    'DejaVu Sans Mono',
    'Liberation Mono',
    'Ubuntu Mono',
    'JetBrains Mono',
    'Fira Code',
  ];

  /// The hooks the description names: the terminal's font list
  /// ([terminalFontsProvider]).
  static ForgeSettingHooks hooks() => ForgeSettingHooks(
    choices: [
      ForgeCallbackChoicesProvider(
        id: terminalFontsProvider,
        onChoices: (_) async => [
          for (final font in terminalFonts)
            ForgeSettingChoice(font, ForgeText.literal(font)),
        ],
      ),
    ],
  );
}

/// The bindings the shell's descriptions store through: the [preferences]
/// service's, the editors' text settings and configuration in the same
/// preferences ([ForgeEditorSettingBinding], which the editor types'
/// descriptions name), the key bindings ([ForgeShortcutsSettingBinding],
/// following [shell]'s live shortcuts when given) and, with [config], the
/// auto-save's.
List<ForgeSettingBinding> forgeShellSettingBindings(
  ForgePreferencesService preferences, {
  ForgeConfigManager? config,
  ForgeKitApi? shell,
}) => [
  ForgePreferencesSettingBinding(preferences),
  ForgeEditorSettingBinding(preferences),
  ForgeShortcutsSettingBinding(preferences, shell: shell),
  ForgeFileTypesSettingBinding(preferences, shell: shell),
  ForgeExternalToolsSettingBinding(preferences),
  if (config != null) ForgeConfigSettingBinding(config),
];

/// A values service over [preferences]' store with the shell's description
/// ([ForgeShellConfiguration.description]) and any further [descriptions],
/// the shell's bindings ([forgeShellSettingBindings]) and [hooks] (default:
/// the shell's own), not loaded yet.
ForgeConfigurationValues forgeShellConfigurationValues(
  ForgePreferencesService preferences, {
  ForgeConfigManager? config,
  ForgeKitApi? shell,
  Iterable<ForgeConfigurationDescription> descriptions = const [],
  ForgeSettingHooks? hooks,
}) => ForgeConfigurationValues(
  preferences.stateStore,
  // Each description's texts under the scope of the module contributing it.
  textScopes: shell == null ? const {} : forgeConfigurationTextScopesOf(shell),
  descriptions: [
    ForgeShellConfiguration.description,
    for (final d in descriptions)
      if (d.id != ForgeShellConfiguration.descriptionId) d,
  ],
  bindings: forgeShellSettingBindings(
    preferences,
    config: config,
    shell: shell,
  ),
  hooks: hooks ?? ForgeShellConfiguration.hooks(),
);

/// The built-in kit module through which the shell contributes its own
/// configuration description ([ForgeShellConfiguration.description]) and its
/// hooks, by the kit's contribution contract
/// ([ForgeConfigurationDescriptionsExtra], [ForgeConfigurationHooksExtra]).
/// The scaffold registers it with its shell once
/// ([ForgeShellConfigurationModule.ensureRegistered]).
class ForgeShellConfigurationModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  /// The module of [shell]'s configuration; without a shell the key binding
  /// sections have no actions to list and are left out.
  ForgeShellConfigurationModule({this.shell});

  /// The shell whose actions the key binding sections list.
  final ForgeKitApi? shell;

  /// Registers a [ForgeShellConfigurationModule] with [shell] unless one is
  /// registered already.
  static void ensureRegistered(DefaultShellApi shell) {
    if (shell.modules.allKitModules.any(
      (module) => module is ForgeShellConfigurationModule,
    )) {
      return;
    }
    shell.registerModule(ForgeShellConfigurationModule(shell: shell));
  }

  @override
  String get displayName => 'Shell configuration';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  late final List<ForgeModuleExtra> ownExtras = [
    ForgeConfigurationDescriptionsExtra([
      ForgeShellConfiguration.description,
      if (shell != null) ForgeShortcutConfiguration.description,
      if (shell != null) ForgeFileTypesConfiguration.description,
    ]),
    ForgeConfigurationHooksExtra(
      ForgeSettingHooks.merged([
        ForgeShellConfiguration.hooks(),
        if (shell case final shell?) ForgeShortcutConfiguration.hooks(shell),
        if (shell case final shell?) ForgeFileTypesConfiguration.hooks(shell),
      ]),
    ),
  ];
}

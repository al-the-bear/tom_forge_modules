import 'package:flutter/material.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'basic_prefs_panel.dart';
import 'config_editors.dart';
import 'config_rail_view.dart';
import 'config_specs.dart';
import 'editor_preferences.dart';
import 'raw_file_module.dart';

/// Hosts the seven custom config editors and the basic-prefs settings panel
/// (`tom_specs_editor_specification.md` §12, step 18).
///
/// Six list editors (queue, queue-templates, profiles, prompt-templates,
/// chat-variables, timed-requests) and one singleton editor (agent-settings)
/// are built from [SpecsConfigSpecs] and exposed as the module's [editors].
/// Each is wired to open its backing YAML/markdown through the injected
/// [RawFileModule] (its "Open raw file" button). The module also contributes
/// one [ForgeAction] per editor — so they are reachable from the command
/// palette — and one [ForgeConfigPanel] for the basic preferences (theme,
/// font, default application, default profile).
///
/// The config editors are *not* file-resolved (they `reject` in `canHandle`);
/// they open via the contributed actions or the dedicated **config rail**
/// ([configRailView], OE-16) — a left-panel launcher listing every editor —
/// both of which call `shell.layout.openEditor`. The basic-prefs panel persists
/// both backing stores on the settings dialog's Save.
class SpecsConfigModule extends ForgeModule {
  /// The host gives the config [specs] (their stores over its workspace),
  /// and the editor [preferences] and agent [settings] as it loaded them —
  /// the basic-prefs panel's starting working copies.
  SpecsConfigModule({
    required SpecsConfigSpecs specs,
    RawFileModule? rawFileModule,
    required EditorPreferencesStore preferencesStore,
    required EditorPreferences preferences,
    required AgentSettings settings,
    this.onPreferencesChanged,
  }) : _specs = specs,
       rawFileModule = rawFileModule ?? RawFileModule(),
       _preferencesStore = preferencesStore,
       _prefs = preferences,
       _settings = settings;

  final SpecsConfigSpecs _specs;

  /// The plain-text module the editors' "Open raw file" buttons target.
  final RawFileModule rawFileModule;

  /// Notified after a basic-prefs Save persists new [EditorPreferences], so the
  /// host can propagate live settings (e.g. YRD9 strict headline mode into the
  /// document controller) without a restart.
  final ValueChanged<EditorPreferences>? onPreferencesChanged;

  final EditorPreferencesStore _preferencesStore;

  ForgeShellApi? _shell;
  final List<ForgeEditor> _editors = [];

  /// The dedicated config rail (OE-16), built on [activate] once the editors
  /// exist. Null before activation; exposed via [configRailView] and [views].
  ConfigRailView? _configRail;

  /// Working copies the basic-prefs panel mutates; persisted on Save. Both
  /// start as the host loaded them.
  EditorPreferences _prefs;
  AgentSettings _settings;

  @override
  String get displayName => 'TomSpecs Config';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    _buildEditors();
  }

  void _buildEditors() {
    Future<void> open(Uri uri) => rawFileModule.openRawFile(uri);
    _editors
      ..clear()
      ..addAll([
        ConfigListEditor(spec: _specs.queueSpec(), onOpenRawFile: open),
        ConfigListEditor(spec: _specs.queueTemplateSpec(), onOpenRawFile: open),
        ConfigListEditor(spec: _specs.profileSpec(), onOpenRawFile: open),
        ConfigListEditor(
          spec: _specs.promptTemplateSpec(),
          onOpenRawFile: open,
        ),
        ConfigListEditor(spec: _specs.chatVariableSpec(), onOpenRawFile: open),
        ConfigListEditor(spec: _specs.timedRequestSpec(), onOpenRawFile: open),
        ConfigObjectEditor(
          spec: _specs.agentSettingsSpec(),
          onOpenRawFile: open,
        ),
      ]);
    _configRail = ConfigRailView(
      editors: List<ForgeEditor>.unmodifiable(_editors),
      onOpen: _openEditor,
    );
  }

  /// The dedicated config rail (OE-16) hosting one launcher per editor. Null
  /// until the module is activated; the shell module hosts it as the DocSpecs
  /// left panel's "Config" tab.
  ConfigRailView? get configRailView => _configRail;

  /// Opens [editor] in the active middle panel via the shell layout.
  void _openEditor(ForgeEditor editor) =>
      _shell?.layout.openEditor(editor, editor.uri);

  @override
  void deactivate() {
    _editors.clear();
    _configRail = null;
    _shell = null;
  }

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors);

  @override
  List<ForgeView> get views => [?_configRail];

  @override
  List<ForgeAction> get actions => [
    for (final editor in _editors)
      ForgeAction(
        id: 'specs.config.open.${editor.uri.path}',
        label: 'Open ${editor.title.value}',
        icon: editor.icon,
        menu: ForgeMenuLocation.tools,
        group: 'config',
        execute: (_) async {
          _openEditor(editor);
          return null;
        },
        isEnabled: () => true,
        isVisible: () => true,
      ),
  ];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeConfigPanel> get configPanels => [
    ForgeConfigPanel(
      id: 'specs.basic-prefs',
      title: 'Basic Preferences',
      icon: Icons.tune_outlined,
      // The profiles are read when the panel opens, so it offers the ones the
      // profile editor saved since.
      builder: (context) => FutureBuilder<List<AgentProfile>>(
        future: _specs.profiles.load(),
        builder: (context, profiles) => profiles.hasData
            ? BasicPrefsPanel(
                prefs: _prefs,
                settings: _settings,
                profiles: profiles.requireData,
                onPrefsChanged: (p) => _prefs = p,
                onSettingsChanged: (s) => _settings = s,
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      onSave: () async {
        await _preferencesStore.save(_prefs);
        await _specs.agentSettings.save(_settings);
        onPreferencesChanged?.call(_prefs);
      },
    ),
  ];
}

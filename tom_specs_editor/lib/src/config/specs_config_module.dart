import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show ForgeModule, ForgeShellApi;

import 'config_editors.dart';
import 'config_rail_view.dart';
import 'config_specs.dart';
import 'editor_preferences.dart';
import 'raw_file_module.dart';
import 'specs_basic_preferences_configuration.dart';

/// Hosts the seven custom config editors and describes the basic preferences
/// (`tom_specs_editor_specification.md` §12, step 18).
///
/// Six list editors (queue, queue-templates, profiles, prompt-templates,
/// chat-variables, timed-requests) and one singleton editor (agent-settings)
/// are built from [SpecsConfigSpecs] and exposed as the module's [editors].
/// Each is wired to open its backing YAML/markdown through the injected
/// [RawFileModule] (its "Open raw file" button). The module also contributes
/// one [ForgeAction] per editor — so they are reachable from the command
/// palette — and the basic preferences (theme, font, default application,
/// strict headline editing, default profile) as a configuration description
/// ([SpecsBasicPreferencesConfiguration]) with the storage bindings of the
/// preferences file and the agent settings, which the application shows as a
/// configuration tile.
///
/// The config editors are *not* file-resolved (they `reject` in `canHandle`);
/// they open via the contributed actions or the dedicated **config rail**
/// ([configRailView], OE-16) — a left-panel launcher listing every editor —
/// both of which call `shell.layout.openEditor`. A changed basic preference is
/// stored at once through its binding.
class SpecsConfigModule extends ForgeModule
    implements ForgeModuleExtrasProvider {
  /// The host gives the config [specs] (their stores over its workspace) and
  /// the editor preferences' [preferencesStore].
  SpecsConfigModule({
    required SpecsConfigSpecs specs,
    RawFileModule? rawFileModule,
    required EditorPreferencesStore preferencesStore,
    this.onPreferencesChanged,
  }) : _specs = specs,
       rawFileModule = rawFileModule ?? RawFileModule(),
       _preferencesStore = preferencesStore;

  final SpecsConfigSpecs _specs;

  /// The plain-text module the editors' "Open raw file" buttons target.
  final RawFileModule rawFileModule;

  /// Notified after a basic preference is stored, with the new
  /// [EditorPreferences], so the host can propagate live settings (e.g. YRD9
  /// strict headline mode into the document controller) without a restart.
  final ValueChanged<EditorPreferences>? onPreferencesChanged;

  final EditorPreferencesStore _preferencesStore;

  ForgeShellApi? _shell;
  final List<ForgeEditor> _editors = [];

  /// The dedicated config rail (OE-16), built on [activate] once the editors
  /// exist. Null before activation; exposed via [configRailView] and [views].
  ConfigRailView? _configRail;

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
  late final List<ForgeModuleExtra> ownExtras = [
    ForgeConfigurationDescriptionsExtra([
      SpecsBasicPreferencesConfiguration.description,
    ]),
    ForgeConfigurationBindingsExtra([
      SpecsEditorPreferencesBinding(
        _preferencesStore,
        onChanged: onPreferencesChanged,
      ),
      SpecsAgentSettingsBinding(_specs.agentSettings),
    ]),
    ForgeConfigurationHooksExtra(
      SpecsBasicPreferencesConfiguration.hooks(_specs.profiles),
    ),
  ];
}

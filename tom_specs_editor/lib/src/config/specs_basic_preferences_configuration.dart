import 'package:flutter/material.dart' show Icons;
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'editor_preferences.dart';

/// The basic preferences (`tom_specs_editor_specification.md` §12 — "Basic
/// prefs → Forge config section": theme, font, default application, strict
/// headline editing, default profile) as a configuration description.
///
/// The values stay where they always were: the editor preferences in
/// `.tom/editor_preferences.yaml` ([SpecsEditorPreferencesBinding], the
/// document `preferences` with the fields of [EditorPreferences.toYaml]) and
/// the default profile in the agent settings, its single source of truth
/// ([SpecsAgentSettingsBinding]). The profiles offered come from the profile
/// store when the choice is shown ([hooks]).
abstract final class SpecsBasicPreferencesConfiguration {
  /// The description's id.
  static const descriptionId = 'tom_specs.basicPreferences';

  /// The section's id.
  static const sectionId = 'basicPreferences';

  /// The choices provider of the profiles.
  static const profilesProvider = 'tom_specs.profiles';

  static ForgeText _text(String id, String fallback) =>
      ForgeText('tom_specs.config.basicPreferences.$id', fallback);

  static ForgeSettingStorage _preference(String field) => ForgeSettingStorage(
    SpecsEditorPreferencesBinding.preferencesKey,
    path: [field],
    binding: SpecsEditorPreferencesBinding.bindingId,
  );

  static ForgeSettingChoice _choice(String value, String label) =>
      ForgeSettingChoice(value, _text('$value.choice', label));

  /// `themeMode`: system, light or dark.
  static final themeMode = ForgeChoiceSetting(
    id: 'themeMode',
    storage: _preference('themeMode'),
    label: _text('themeMode', 'Theme'),
    defaultValue: const EditorPreferences().themeMode,
    choices: [
      _choice('system', 'System'),
      _choice('light', 'Light'),
      _choice('dark', 'Dark'),
    ],
  );

  /// `fontFamily`: the editor font family (`system`: the platform's).
  static final fontFamily = ForgeChoiceSetting(
    id: 'fontFamily',
    storage: _preference('fontFamily'),
    label: _text('fontFamily', 'Font family'),
    defaultValue: const EditorPreferences().fontFamily,
    display: ForgeChoiceDisplay.dropdown,
    choices: [
      _choice('system', 'System'),
      _choice('monospace', 'Monospace'),
      _choice('serif', 'Serif'),
      _choice('sans-serif', 'Sans serif'),
    ],
  );

  /// `defaultApplication`: the application shown on launch.
  static final defaultApplication = ForgeChoiceSetting(
    id: 'defaultApplication',
    storage: _preference('defaultApplication'),
    label: _text('defaultApplication', 'Default application'),
    defaultValue: const EditorPreferences().defaultApplication,
    choices: [
      _choice('DocSpecs', 'DocSpecs'),
      _choice('CodeSpecs', 'CodeSpecs'),
      _choice('Implementation', 'Implementation'),
    ],
  );

  /// `strictHeadlineEditing` (YRD9).
  static final strictHeadlineEditing = ForgeBoolSetting(
    id: 'strictHeadlineEditing',
    storage: _preference('strictHeadlineEditing'),
    label: _text('strictHeadlineEditing', 'Strict headline editing'),
    help: _text(
      'strictHeadlineEditing.help',
      'Edit headlines/ids only on list-entry sections; fixed sections stay '
          'read-only.',
    ),
    defaultValue: const EditorPreferences().strictHeadlineEditing,
  );

  /// The agent settings' `defaultProfileId`; *none*: the first profile.
  static final defaultProfile = ForgeChoiceSetting(
    id: 'defaultProfile',
    storage: const ForgeSettingStorage(
      SpecsAgentSettingsBinding.defaultProfileKey,
      binding: SpecsAgentSettingsBinding.bindingId,
    ),
    label: _text('defaultProfile', 'Default profile'),
    defaultValue: '',
    allowNone: true,
    noneLabel: _text('defaultProfile.none', '(none)'),
    choicesProvider: profilesProvider,
    display: ForgeChoiceDisplay.dropdown,
  );

  /// The description.
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: _text('description', 'Basic Preferences'),
    sections: [
      ForgeSettingsSection(
        id: sectionId,
        title: _text('title', 'Basic Preferences'),
        icon: ForgeIconRef(Icons.tune_outlined.codePoint),
        order: 100,
        settings: [
          themeMode,
          fontFamily,
          defaultApplication,
          strictHeadlineEditing,
          defaultProfile,
        ],
      ),
    ],
  );

  /// The profiles of [profiles] as the default profile's choices, read each
  /// time the choice is shown, so it offers the ones saved since.
  static ForgeSettingHooks hooks(AgentProfileStore profiles) =>
      ForgeSettingHooks(
        choices: [
          ForgeCallbackChoicesProvider(
            id: profilesProvider,
            onChoices: (_) async => [
              for (final profile in await profiles.load())
                ForgeSettingChoice(profile.id, ForgeText.literal(profile.name)),
            ],
          ),
        ],
      );
}

/// The editor preferences file as a storage binding: the document
/// [preferencesKey] is [EditorPreferences.toYaml], read from and saved to
/// the [store] (`.tom/editor_preferences.yaml`) as before.
class SpecsEditorPreferencesBinding extends ForgeSettingBinding {
  SpecsEditorPreferencesBinding(this.store, {this.onChanged});

  /// The binding's id.
  static const bindingId = 'tom_specs.editorPreferences';

  /// The one document.
  static const preferencesKey = 'preferences';

  /// The file the preferences are kept in.
  final EditorPreferencesStore store;

  /// Told the preferences after each save (the host applies live settings,
  /// e.g. strict headline editing, without a restart).
  final void Function(EditorPreferences preferences)? onChanged;

  Future<void> _writing = Future.value();

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async =>
      key == preferencesKey ? (await store.load()).toYaml() : null;

  @override
  Future<void> write(String key, Object? document) {
    if (key != preferencesKey) return Future.value();
    final preferences = document is Map
        ? EditorPreferences.fromYaml(document.cast<String, dynamic>())
        : const EditorPreferences();
    return _writing = _writing.then((_) async {
      await store.save(preferences);
      onChanged?.call(preferences);
    });
  }

  @override
  Future<void> flushed() => _writing;
}

/// The agent settings' default profile as a storage binding: the document
/// [defaultProfileKey] is [AgentSettings.defaultProfileId] (`""` none). A
/// write loads the settings first and changes only that field, so what the
/// Agent Settings editor saved meanwhile is kept.
class SpecsAgentSettingsBinding extends ForgeSettingBinding {
  SpecsAgentSettingsBinding(this.store);

  /// The binding's id.
  static const bindingId = 'tom_specs.agentSettings';

  /// The one document.
  static const defaultProfileKey = 'defaultProfileId';

  /// The agent settings' store.
  final AgentSettingsStore store;

  Future<void> _writing = Future.value();

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async =>
      key == defaultProfileKey ? (await store.load()).defaultProfileId : null;

  @override
  Future<void> write(String key, Object? document) {
    if (key != defaultProfileKey) return Future.value();
    final id = document is String && document.isNotEmpty ? document : null;
    return _writing = _writing.then((_) async {
      final yaml = (await store.load()).toYaml();
      if (id == null) {
        yaml.remove(defaultProfileKey);
      } else {
        yaml[defaultProfileKey] = id;
      }
      await store.save(AgentSettings.fromYaml(yaml));
    });
  }

  @override
  Future<void> flushed() => _writing;
}

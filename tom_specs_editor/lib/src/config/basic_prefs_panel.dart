import 'package:flutter/material.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';

import 'editor_preferences.dart';

/// The basic-preferences settings panel (§12 — "Basic prefs → Forge config
/// section": theme, font, default app, default profile).
///
/// Unlike the seven config editors, basic prefs is *not* a custom editor — it
/// is a [ForgeConfigPanel] surfaced in the shell's settings dialog. This widget
/// edits two backing models in place: the editor [EditorPreferences] (theme /
/// font / default application) and the default **profile**, which lives in
/// [AgentSettings] (the single source of truth). The hosting module persists
/// both on the dialog's Save.
///
/// The widget mutates the shared working copies via [onPrefsChanged] /
/// [onSettingsChanged] rather than holding its own state, so the module's
/// `onSave` writes exactly what the user sees.
class BasicPrefsPanel extends StatefulWidget {
  const BasicPrefsPanel({
    super.key,
    required this.prefs,
    required this.settings,
    required this.profiles,
    required this.onPrefsChanged,
    required this.onSettingsChanged,
  });

  /// The current editor preferences (theme / font / default app).
  final EditorPreferences prefs;

  /// The current agent settings — only [AgentSettings.defaultProfileId] is
  /// edited here; the rest is owned by the Agent Settings editor.
  final AgentSettings settings;

  /// The available profiles, used to populate the default-profile dropdown.
  final List<AgentProfile> profiles;

  final ValueChanged<EditorPreferences> onPrefsChanged;
  final ValueChanged<AgentSettings> onSettingsChanged;

  @override
  State<BasicPrefsPanel> createState() => _BasicPrefsPanelState();
}

class _BasicPrefsPanelState extends State<BasicPrefsPanel> {
  late EditorPreferences _prefs = widget.prefs;
  late AgentSettings _settings = widget.settings;

  static const _themeModes = ['system', 'light', 'dark'];
  static const _fontFamilies = ['system', 'monospace', 'serif', 'sans-serif'];
  static const _applications = ['DocSpecs', 'CodeSpecs', 'Implementation'];

  /// Sentinel value for "no default profile" in the dropdown — [AgentSettings]
  /// stores this as a null [AgentSettings.defaultProfileId].
  static const _noProfile = '';

  void _setPrefs(EditorPreferences next) {
    setState(() => _prefs = next);
    widget.onPrefsChanged(next);
  }

  void _setDefaultProfile(String? id) {
    // copyWith can't clear to null (its `??` keeps the old value), so the
    // "(none)" choice goes through the full constructor.
    final next = (id == null || id == _noProfile)
        ? AgentSettings(
            bridgeHost: _settings.bridgeHost,
            portScanStart: _settings.portScanStart,
            portScanEnd: _settings.portScanEnd,
            maxTokens: _settings.maxTokens,
            maxRounds: _settings.maxRounds,
            thinkingEnabled: _settings.thinkingEnabled,
            promptCachingEnabled: _settings.promptCachingEnabled,
            toolApprovalMode: _settings.toolApprovalMode,
          )
        : _settings.copyWith(defaultProfileId: id);
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dropdown(
          key: const Key('prefs-theme'),
          label: 'Theme',
          value: _prefs.themeMode,
          items: _themeModes,
          onChanged: (v) => _setPrefs(_prefs.copyWith(themeMode: v)),
        ),
        const SizedBox(height: 12),
        _dropdown(
          key: const Key('prefs-font'),
          label: 'Font family',
          value: _prefs.fontFamily,
          items: _fontFamilies,
          onChanged: (v) => _setPrefs(_prefs.copyWith(fontFamily: v)),
        ),
        const SizedBox(height: 12),
        _dropdown(
          key: const Key('prefs-default-app'),
          label: 'Default application',
          value: _prefs.defaultApplication,
          items: _applications,
          onChanged: (v) => _setPrefs(_prefs.copyWith(defaultApplication: v)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const Key('prefs-strict-headlines'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Strict headline editing'),
          subtitle: const Text(
              'Edit headlines/ids only on list-entry sections; fixed sections '
              'stay read-only.'),
          value: _prefs.strictHeadlineEditing,
          onChanged: (v) =>
              _setPrefs(_prefs.copyWith(strictHeadlineEditing: v)),
        ),
        const SizedBox(height: 12),
        _dropdown(
          key: const Key('prefs-default-profile'),
          label: 'Default profile',
          value: _settings.defaultProfileId ?? _noProfile,
          items: [_noProfile, for (final p in widget.profiles) p.id],
          labelOf: (id) => id == _noProfile
              ? '(none)'
              : widget.profiles
                  .firstWhere((p) => p.id == id,
                      orElse: () => AgentProfile(id: id, name: id))
                  .name,
          onChanged: _setDefaultProfile,
        ),
      ],
    );
  }

  Widget _dropdown({
    required Key key,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String value)? labelOf,
  }) {
    final values = items.contains(value) ? items : [value, ...items];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: key,
          isDense: true,
          isExpanded: true,
          value: value,
          items: [
            for (final item in values)
              DropdownMenuItem<String>(
                value: item,
                child: Text(labelOf?.call(item) ?? item),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

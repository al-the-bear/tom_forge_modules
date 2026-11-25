import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The Dart editor's options as a configuration description: the shared
/// text settings ([ForgeEditorSettings.textGroups]) and the Dart editor's
/// own (toolbar, autocompletion, diagnostics, toolbar buttons), stored in
/// the editor-specific configuration of `dart` under the keys the editor
/// reads.
abstract final class ForgeDartEditorConfiguration {
  /// The editor type id the settings are stored under.
  static const editorTypeId = 'dart';

  /// The description's id.
  static const descriptionId = 'forge.editor.dart';

  /// The id of its one section.
  static const sectionId = 'editor';

  /// `<description>/<section>` (`ForgeConfigurationSectionRef.id`).
  static const sectionRef = '$descriptionId/$sectionId';

  static ForgeBoolSetting _toggle(
    String key,
    String label, {
    String? id,
    bool defaultValue = true,
  }) => ForgeEditorSettings.toggle(
    editorTypeId,
    key,
    label,
    id: id,
    defaultValue: defaultValue,
  );

  static ForgeText _title(String id, String text) =>
      ForgeText('forge.config.dart.$id', text);

  /// The description.
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: const ForgeText('forge.config.dart.description', 'Dart Editor'),
    sections: [
      ForgeSettingsSection(
        id: sectionId,
        title: const ForgeText('forge.config.dart.title', 'Dart Editor'),
        icon: ForgeIconRef(Icons.code.codePoint),
        order: 2,
        settings: [
          ...ForgeEditorSettings.textGroups(editorTypeId),
          ForgeSettingsGroup(
            id: 'toolbar',
            title: _title('toolbar', 'Toolbar'),
            settings: [
              _toggle('showToolbar', 'Show toolbar'),
              // The editor's own line-number column, apart from the text
              // setting of the same name.
              _toggle(
                'showLineNumbers',
                'Line numbers',
                id: 'toolbarLineNumbers',
              ),
            ],
          ),
          ForgeSettingsGroup(
            id: 'autocompletion',
            title: _title('autocompletion', 'Autocompletion'),
            settings: [
              _toggle('autoCompleteEnabled', 'Enabled'),
              _toggle('popupPreferBelow', 'Popup below'),
              ForgeIntSetting(
                id: 'maxCompletionItems',
                storage: ForgeEditorSettings.specific(
                  editorTypeId,
                  'maxCompletionItems',
                ),
                label: const ForgeText(
                  'forge.config.dart.maxCompletionItems.label',
                  'Max items',
                ),
                defaultValue: 8,
                min: 1,
              ),
            ],
          ),
          ForgeSettingsGroup(
            id: 'diagnosticsErrors',
            title: _title('diagnosticsErrors', 'Diagnostics — Errors'),
            settings: [
              _toggle('showErrorTooltips', 'Tooltips'),
              _toggle('showErrorMarkers', 'Markers'),
            ],
          ),
          ForgeSettingsGroup(
            id: 'diagnosticsWarnings',
            title: _title('diagnosticsWarnings', 'Diagnostics — Warnings'),
            settings: [
              _toggle('showWarningTooltips', 'Tooltips'),
              _toggle('showWarningMarkers', 'Markers'),
            ],
          ),
          ForgeSettingsGroup(
            id: 'diagnosticsInfo',
            title: _title('diagnosticsInfo', 'Diagnostics — Info'),
            settings: [
              _toggle('showInfoTooltips', 'Tooltips', defaultValue: false),
              _toggle('showInfoMarkers', 'Markers', defaultValue: false),
            ],
          ),
          ForgeSettingsGroup(
            id: 'toolbarButtons',
            title: _title('toolbarButtons', 'Toolbar Buttons'),
            settings: [
              _toggle('showAutoCompleteToggle', 'Autocomplete toggle'),
              _toggle('showErrorToggles', 'Error toggles'),
              _toggle('showWarningToggles', 'Warning toggles'),
              _toggle('showInfoToggles', 'Info toggles'),
              _toggle('showPopupPositionToggle', 'Popup position'),
              _toggle('showOpenReferenceButton', 'Open reference'),
            ],
          ),
        ],
      ),
    ],
  );
}

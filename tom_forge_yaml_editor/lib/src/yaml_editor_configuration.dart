import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The YAML editor's options as a configuration description: the shared
/// text settings ([ForgeEditorSettings.textGroups]) and the YAML editor's
/// own (tree and structure, the schema folder, layout), stored in the
/// editor-specific configuration of `yaml` under the keys the editor reads.
abstract final class ForgeYamlEditorConfiguration {
  /// The editor type id the settings are stored under.
  static const editorTypeId = 'yaml';

  /// The description's id.
  static const descriptionId = 'forge.editor.yaml';

  /// The id of its one section.
  static const sectionId = 'editor';

  /// `<description>/<section>` (`ForgeConfigurationSectionRef.id`).
  static const sectionRef = '$descriptionId/$sectionId';

  static ForgeBoolSetting _toggle(String key, String label) =>
      ForgeEditorSettings.toggle(editorTypeId, key, label);

  static ForgeText _title(String id, String text) =>
      ForgeText('forge.config.yaml.$id', text);

  /// The description.
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: const ForgeText('forge.config.yaml.description', 'YAML Editor'),
    sections: [
      ForgeSettingsSection(
        id: sectionId,
        title: const ForgeText('forge.config.yaml.title', 'YAML Editor'),
        icon: ForgeIconRef(Icons.data_object.codePoint),
        order: 3,
        settings: [
          ...ForgeEditorSettings.textGroups(editorTypeId),
          ForgeSettingsGroup(
            id: 'treeAndStructure',
            title: _title('treeAndStructure', 'Tree & Structure'),
            settings: [
              _toggle('showTreeLines', 'Tree lines'),
              _toggle('showCollapseToggles', 'Collapse toggles'),
              _toggle('showAddButtons', 'Add buttons'),
              _toggle('showRemoveButtons', 'Remove buttons'),
              _toggle('showInlineValidation', 'Inline validation'),
            ],
          ),
          ForgeSettingsGroup(
            id: 'schema',
            title: _title('schema', 'Schema'),
            settings: [
              ForgePathSetting(
                id: 'yamlSchemasPath',
                storage: ForgeEditorSettings.specific(
                  editorTypeId,
                  'yamlSchemasPath',
                ),
                label: const ForgeText(
                  'forge.config.yaml.yamlSchemasPath.label',
                  'JSON Schema directory',
                ),
                pathKind: ForgePathKind.folder,
              ),
            ],
          ),
          ForgeSettingsGroup(
            id: 'layout',
            title: _title('layout', 'Layout'),
            settings: [
              ForgeIntSetting(
                id: 'indentWidth',
                storage: ForgeEditorSettings.specific(
                  editorTypeId,
                  'indentWidth',
                ),
                label: const ForgeText(
                  'forge.config.yaml.indentWidth.label',
                  'Indent',
                ),
                defaultValue: 24,
                min: 1,
              ),
              ForgeIntSetting(
                id: 'collapsedPreviewLines',
                storage: ForgeEditorSettings.specific(
                  editorTypeId,
                  'collapsedPreviewLines',
                ),
                label: const ForgeText(
                  'forge.config.yaml.collapsedPreviewLines.label',
                  'Preview lines',
                ),
                defaultValue: 2,
                min: 0,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

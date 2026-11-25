import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The Markdown editor's options as a configuration description: the shared
/// text settings ([ForgeEditorSettings.textGroups]) and the Markdown
/// editor's own (layout, raw editor, main panel, tree, features, code
/// blocks, tables, search, behaviour, the schema folder), stored in the
/// editor-specific configuration of `md` under the keys the editor reads.
abstract final class ForgeMarkdownEditorConfiguration {
  /// The editor type id the settings are stored under.
  static const editorTypeId = 'md';

  /// The description's id.
  static const descriptionId = 'forge.editor.md';

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

  static ForgeSettingsGroup _group(
    String id,
    String title,
    List<ForgeSetting<Object>> settings,
  ) => ForgeSettingsGroup(
    id: id,
    title: ForgeText('forge.config.md.$id', title),
    settings: settings,
  );

  /// The description.
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: const ForgeText('forge.config.md.description', 'Markdown Editor'),
    sections: [
      ForgeSettingsSection(
        id: sectionId,
        title: const ForgeText('forge.config.md.title', 'Markdown Editor'),
        icon: ForgeIconRef(Icons.description_outlined.codePoint),
        order: 4,
        settings: [
          ...ForgeEditorSettings.textGroups(editorTypeId),
          _group('layout', 'Layout', [
            _toggle('showTree', 'Show tree'),
            _toggle('showToolbar', 'Show toolbar', defaultValue: false),
            _toggle('showStatusBar', 'Show status bar'),
            _toggle('showSearchBox', 'Show search box'),
          ]),
          _group('rawEditor', 'Raw Editor', [
            _toggle('autoHideEditor', 'Auto-hide editor'),
            _toggle('livePreview', 'Live preview'),
            _toggle('allowEditorPositionChange', 'Allow position change'),
          ]),
          _group('mainPanel', 'Main Panel', [
            // The main panel's line numbers, apart from the text setting of
            // the same name.
            _toggle(
              'showLineNumbers',
              'Line numbers',
              id: 'mainPanelLineNumbers',
              defaultValue: false,
            ),
            _toggle('showSectionBorders', 'Section borders'),
            _toggle('highlightCurrentSection', 'Highlight section'),
            _toggle('enableSmoothScrolling', 'Smooth scrolling'),
          ]),
          _group('tree', 'Tree', [
            _toggle('expandAllByDefault', 'Expand all'),
            _toggle('showValidationMarkers', 'Validation markers'),
            _toggle('enableDragAndDrop', 'Drag and drop'),
            _toggle('showSectionIcons', 'Section icons', defaultValue: false),
          ]),
          _group('features', 'Markdown Features', [
            _toggle('enableMermaid', 'Mermaid diagrams'),
            _toggle('enableMath', 'Math (KaTeX)'),
            _toggle('enableFootnotes', 'Footnotes'),
            _toggle('enableTaskLists', 'Task lists'),
            _toggle('enableInteractiveTaskLists', 'Interactive tasks'),
            _toggle('enableTables', 'Tables'),
            _toggle('enableSyntaxHighlighting', 'Syntax highlighting'),
          ]),
          _group('codeBlocks', 'Code Blocks', [
            _toggle('showCodeBlockLanguage', 'Show language'),
            _toggle('showCopyCodeButton', 'Copy button'),
            _toggle('showCodeEditButton', 'Edit button'),
            _toggle('enableCodeEditing', 'Enable editing'),
          ]),
          _group('tables', 'Tables', [
            _toggle('showTableEditButton', 'Edit button'),
            _toggle('enableTableEditing', 'Enable editing'),
          ]),
          _group('search', 'Search', [
            _toggle('enableSearch', 'Search'),
            _toggle('enableReplace', 'Replace'),
            _toggle('enableRegexSearch', 'Regex', defaultValue: false),
          ]),
          _group('behavior', 'Behavior', [
            _toggle('readOnly', 'Read only', defaultValue: false),
            _toggle('confirmDelete', 'Confirm delete'),
            _toggle('autoSave', 'Auto save', defaultValue: false),
          ]),
          _group('schema', 'Schema', [
            ForgePathSetting(
              id: 'docspecSchemasPath',
              storage: ForgeEditorSettings.specific(
                editorTypeId,
                'docspecSchemasPath',
              ),
              label: const ForgeText(
                'forge.config.md.docspecSchemasPath.label',
                'DocSpec schema directory',
              ),
              pathKind: ForgePathKind.folder,
            ),
          ]),
        ],
      ),
    ],
  );
}

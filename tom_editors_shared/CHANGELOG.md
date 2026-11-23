# Changelog

## Unreleased

- **Breaking:** the editor-specific action sets and standalone
  integrations moved into their editors: `MdEditorActions`,
  `MdStandaloneIntegration` and `MdEditorDefaults` to `tom_md_editor`;
  `DartEditorActions`, `DartStandaloneIntegration` and `DartEditorDefaults`
  to `tom_dart_editor`; `YamlEditorActions` to `tom_yaml_editor`. Import them
  from the editor's library. The generic parts stay here
  (`StandardEditingActions`, `BaseStandaloneIntegration`, the descriptors).
- **Breaking:** `TextEditorCore`, `TextEditorTheme` and `TextMarker` /
  `TextMarkerType` are removed. The source editor is `tom_file_editors`'
  `TomTextSource` (look: `TomTextSourceStyle`; markers: `TomTextMarker` /
  `TomTextMarkerSeverity`; the line edits: `TomLineEdits`).

## 0.1.0

- Initial release.

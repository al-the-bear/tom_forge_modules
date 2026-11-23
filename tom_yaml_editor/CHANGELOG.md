# Changelog

## Unreleased

- `YamlEditorActions` (the YAML editor's own actions) moved here from
  `tom_editors_shared`; exported by `tom_yaml_editor.dart`.
- **Breaking:** text mode and the subtree inspector draw through
  `tom_file_editors`' `TomTextSource` instead of `tom_editors_shared`'s
  removed `TextEditorCore`. `SchemaMarkerGenerator.generate` answers
  `TomTextMarker`s (`severity` instead of `type`). Look, highlighting,
  markers, line numbers and the editing actions stay; the source view gains
  find (Cmd/Ctrl+F). The clipboard and line-editing actions of the action
  integration run on the source only while text mode shows it.
- `YamlSyntaxHighlighter` is the shared `YamlHighlighter` of
  `tom_text_highlight` (the one YAML tokenizer of the Forge editors and
  `tom_file_editors`) in the editor's `YamlHighlightColors`. The colours are
  unchanged; trailing comments on list items, a lone `-`, nested dashes and
  `|+` / `>2` block indicators are now coloured as such. The spans' `type`
  labels are the shared token classes (`attr`, `punctuation.colon`,
  `bullet`, `meta`, ...).

## 0.1.0

- Initial project structure
- Core architecture: non-destructive YAML model, schema walker, editor registry
- Convention-based embedded editor system (`key-<type>:` pattern)
- Customizable theming system

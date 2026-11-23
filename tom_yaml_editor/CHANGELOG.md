# Changelog

## Unreleased

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

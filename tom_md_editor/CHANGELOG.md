## Unreleased

* The Markdown editor's own actions are this package's: `MdEditorActions`,
  `MdStandaloneIntegration` and `MdEditorDefaults` moved here from
  `tom_editors_shared` and are exported by `tom_md_editor.dart`.
* Code blocks are highlighted through `tom_text_highlight` (YAML, Markdown,
  JSON, shell, `.env`) in the same theme colours; a block in another
  language is plain. The overlay's `code_text_field` controller highlights
  through it too, and the raw editor's `MdSyntaxHighlightController` takes a
  `SyntaxHighlighter` (default `MdRawSyntaxHighlighter`, its own rules). No
  direct dependency on `highlight` or `flutter_highlight` any more.
* Plugin packages: Mermaid (`tom_md_mermaid`), math (`tom_md_math`), DocSpecs
  schemas (`tom_md_docspecs`), reviews (`tom_md_review`) and the HTTP document
  provider (`tom_md_http`) moved out of the core, which depends on none of
  them. Extension points: `MdEditor.plugins` / `MdPreviewPanel.plugins` and
  `createDefaultPluginRegistry(plugins:)` (core plugins: table, code),
  `MdContentPlugin.isEnabledBy`, `inlineSyntaxes` and `inlineBuilders`,
  `MdSchemaSupport` with `MdEditorController.setSchemaSupport` /
  `schemaSupport` / `hasSchema`, and `MdEditorController.editStructure`.
* Guarded line edits (`MdLineEdit`, `applyLineEdit`).
* Browsing: `MdLinkResolver`, `MdNavigationHistory`, `MdBrowserNavigator`,
  `MdFollowTail`, `MdFileFollower` and `MdEditorSettings.followTail`.
* Front matter: a file's leading YAML front matter (`---` … `---`) is shown
  verbatim in the rendered view instead of as a rule and a setext heading,
  and is no section (`MdFrontMatter`); a schema comment after it is found.
* Editing a section keeps everything before the first heading: the parsed
  document holds it as `MdDocument.preamble`, which `MdParser.toMarkdown`
  writes back. Before, a section edit rewrote the file without its front
  matter, its schema comment and any introductory text.

## 0.0.1

* TODO: Describe initial release.

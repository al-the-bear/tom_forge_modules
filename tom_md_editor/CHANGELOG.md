## Unreleased

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

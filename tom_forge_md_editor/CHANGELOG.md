# Changelog

## Unreleased

- `ForgeMarkdownEditorConfiguration`: the Markdown editor's options as a
  configuration description (the shared text settings and the editor's
  layout, raw editor, main panel, tree, features, code blocks, tables,
  search, behaviour and schema folder), given to
  `forgeMarkdownEditorType.configuration`; the panel shell shows it as the
  *Markdown Editor* section in place of its hand-written one, same keys and
  defaults.
- `forgeMarkdownEditorType` carries the editor's own actions
  (`ForgeKitEditorType.actionDescriptors`: `MdEditorActions.descriptors`, now
  the editor package's), which the panel shell lists before an editor is
  open.
- The Markdown file kind `forgeMarkdownFileKind` (a `ForgeKitFileKind`) and its editor
  `ForgeMarkdownFileEditor`, moved here from `tom_forge_file_editors`: the editor
  over a `ForgeFileSession`, bound through the kit's `ForgeSessionFile` and
  framed by `tom_forge_shared_ui`'s `ForgeSessionFileFrame`, now also taking
  the application's `ForgeKitApi` (`api:`). An application registers the
  kind with its file module; nothing registers itself on import. The undo
  conformance run moved with it; its subject is in `tom_forge_md_editor_testing`.
- Depends on `tom_forge_shared_ui`.

## 0.1.0

- `ForgeMdEditor` and its editor type `forgeMarkdownEditorType`, moved out of
  `tom_forge_code_editors` with their history. The adapter is built on the
  Forge kit instead of the panel shell: it takes a `ForgeKitModule` (and
  optionally the `ForgeKitApi`) where it took the shell's `ForgeModule`, and
  its type is the kit's `ForgeKitEditorType`.

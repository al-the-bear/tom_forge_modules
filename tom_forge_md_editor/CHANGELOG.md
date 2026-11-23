# Changelog

## Unreleased

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

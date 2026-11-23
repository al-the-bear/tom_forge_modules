# Changelog

## 0.1.0

- `ForgeMdEditor` and its editor type `forgeMarkdownEditorType`, moved out of
  `tom_forge_code_editors` with their history. The adapter is built on the
  Forge kit instead of the panel shell: it takes a `ForgeKitModule` (and
  optionally the `ForgeKitApi`) where it took the shell's `ForgeModule`, and
  its type is the kit's `ForgeKitEditorType`.

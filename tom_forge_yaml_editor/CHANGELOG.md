# Changelog

## Unreleased

- `ForgeYamlEditorConfiguration`: the YAML editor's options as a
  configuration description (the shared text settings, tree and structure,
  the JSON Schema folder, layout), given to `forgeYamlEditorType.configuration`;
  the panel shell shows it as the *YAML Editor* section in place of its
  hand-written one, same keys and defaults.
- `forgeYamlEditorType` carries the editor's own actions
  (`ForgeKitEditorType.actionDescriptors`: `YamlEditorActions.descriptors`, now
  the editor package's), which the panel shell lists before an editor is
  open.
- The YAML file kind `forgeYamlFileKind` (a `ForgeKitFileKind`) and its editor
  `ForgeYamlFileEditor`, moved here from `tom_forge_file_editors`: the editor
  over a `ForgeFileSession`, bound through the kit's `ForgeSessionFile` and
  framed by `tom_forge_shared_ui`'s `ForgeSessionFileFrame`, now also taking
  the application's `ForgeKitApi` (`api:`). An application registers the
  kind with its file module; nothing registers itself on import. The undo
  conformance run moved with it; its subject is in `tom_forge_yaml_editor_testing`.
- Depends on `tom_forge_shared_ui`.

## 0.1.0

- `ForgeYamlEditor` and its editor type `forgeYamlEditorType`, moved out of
  `tom_forge_code_editors` with their history. The adapter is built on the
  Forge kit instead of the panel shell: it takes a `ForgeKitModule` (and
  optionally the `ForgeKitApi`) where it took the shell's `ForgeModule`, and
  its type is the kit's `ForgeKitEditorType`.

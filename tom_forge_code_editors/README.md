# Tom Forge Code Editors

Forge's code editors in the panel shell (`tom_forge_shell`): the adapters that
make the Markdown (`tom_md_editor`), Dart (`tom_dart_editor`) and YAML
(`tom_yaml_editor`) editors shell editors (`ForgeMdEditor`, `ForgeDartEditor`,
`ForgeYamlEditor`), the Dart outline provider, and the editor types the layout
controller opens `.md`/`.markdown`, `.dart` and `.yaml`/`.yml` files with.

`forgeCodeEditorComponents` holds the three editor types as
`ForgeShellComponents`. Extensions keep the typed helpers: where the Dart editor
reads its analysis summaries (`layout.dartSummaryAssets`, on a
`DefaultLayoutController`) and the shell module's `registerMdEditor` /
`mdEditors` and their Dart and YAML twins.

Part of Tom Forge; the layers are in `tom_forge/_copilot_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

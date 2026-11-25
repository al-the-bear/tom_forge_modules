# Tom Forge Code Editors

**Kept for one release.** The Markdown, Dart and YAML editor adapters are
packages of their own on the Forge kit — `tom_forge_md_editor`,
`tom_forge_dart_editor` and `tom_forge_yaml_editor` — and an application takes
only the ones it uses. This package re-exports the three so its users keep
compiling, with the shell-typed helpers it had:

- `forgeCodeEditorComponents`: the three editor types as
  `ForgeShellComponents` (new code: `ForgeShellComponents(editorTypes:
  [forgeMarkdownEditorType, forgeDartEditorType, forgeYamlEditorType])`);
- `dartSummaryAssets` on a `DefaultLayoutController`: where the Dart editors it
  opens read their analysis summaries (new code:
  `ForgeDartSummariesByHost.of(layout)` / `.set(layout, assets)` of
  `tom_forge_dart_editor`);
- `registerMdEditor` / `mdEditors` and their Dart and YAML twins on the shell's
  module (new code: `registerEditor` and `editors.whereType<...>()`).

Part of Tom Forge; the layers are in `tom_ai/forge_modules/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

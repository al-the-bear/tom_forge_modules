# Tom Forge YAML Editor

Forge's YAML editor adapter. `ForgeYamlEditor` makes the YAML editor
(`tom_yaml_editor`: the schema-aware structure view and its source view) a
Forge editor (`ForgeSchemaEditor`) over the Forge kit: title, dirty state,
content, the editing actions of the text mode, and the parse and schema errors
as diagnostics.

It is a package of its own so an application takes the adapters it uses and
nothing of the others' editors.

## How it reaches the application

The adapter takes a `ForgeKitModule` and, optionally, the `ForgeKitApi` of the
application (`api:`). Without one it asks the module (`forgeKitApiOf`: a
module that implements `ForgeKitApiProvider`, as the panel shell's own module
does). With an API it routes the editing actions and key bindings through it
(`ShellEditorIntegration`), reads its editor settings
(`getEditorSpecificConfig('yaml')`) and reports diagnostics; without one the
editor works on its own.

## Registering

The package exports its editor type, the kit's `ForgeKitEditorType`
(`forgeYamlEditorType`: `.yaml`, `.yml`). An application takes it with the
other types it opens files with; the panel shell:

```dart
final components = ForgeShellComponents(editorTypes: [forgeYamlEditorType]);
```

## Dependencies

`tom_yaml_editor`, `tom_forge_kit`, `tom_forge_core`, `tom_editors_shared` —
never `tom_forge_shell` (`tom_forge_app/test/platform_layering_test.dart`
PL-8). It brings no analyzer, webview, Mermaid or math renderer. Layer 3 of
`tom_forge/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

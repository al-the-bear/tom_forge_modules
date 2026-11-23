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

## The file kind

The package also exports its file kind, the kit's `ForgeKitFileKind`
(`forgeYamlFileKind`: `.yaml`, `.yml`), whose editor `ForgeYamlFileEditor` reads and saves its file
through a `ForgeFileSession`: the controller keeps the one history, the
session the bytes (encoding, byte-order mark and line endings kept), the
editor saves its own file and a file changed on disk is not written over
(`ForgeSessionFileFrame` shows its state). An application registers the kind
with the module that opens its files; importing the package registers
nothing. Tom Forge:

```dart
ForgeFileEditorsModule(
  fileKinds: ForgeFileKindRegistry([forgeYamlFileKind]),
);
```

## Testing

`ForgeYamlFileEditor` passes Forge's undo conformance harness with no check skipped
(`test/undo_conformance_test.dart`). The subject that drives it,
`ForgeYamlFileSubject`, is in the test-support package `tom_forge_yaml_editor_testing`
(a dev_dependency), so an application composing the kind runs the same
checks; the suites make the kind's editors with `tom_forge_ui_testing`'s
`ForgeFileKindTestBed`.

## Dependencies

`tom_yaml_editor`, `tom_forge_kit`, `tom_forge_shared_ui`, `tom_forge_core`,
`tom_editors_shared` —
never `tom_forge_shell` (`tom_forge_app/test/platform_layering_test.dart`
PL-8); test support only as dev_dependencies. It brings no analyzer, webview, Mermaid or math renderer. Layer 3 of
`tom_forge/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

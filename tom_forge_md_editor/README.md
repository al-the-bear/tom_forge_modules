# Tom Forge Markdown Editor

Forge's Markdown editor adapter. `ForgeMdEditor` makes the Markdown editor
(`tom_md_editor`) a Forge text editor (`ForgeTextEditor`) over the Forge kit:
document, cursor, selections, decorations, dirty state, the editing actions,
and the docspec validation as diagnostics.

It is a package of its own so an application takes the adapters it uses and
nothing of the others' editors.

## How it reaches the application

The adapter takes a `ForgeKitModule` and, optionally, the `ForgeKitApi` of the
application (`api:`). Without one it asks the module (`forgeKitApiOf`: a
module that implements `ForgeKitApiProvider`, as the panel shell's own module
does). With an API it routes the editing actions and key bindings through it
(`ShellEditorIntegration`), reads its editor settings
(`getEditorSpecificConfig('md')`) and reports diagnostics; without one the
editor works on its own.

## Registering

The package exports its editor type, the kit's `ForgeKitEditorType`
(`forgeMarkdownEditorType`: `.md`, `.markdown`). An application takes it with
the other types it opens files with; the panel shell:

```dart
final components = ForgeShellComponents(editorTypes: [forgeMarkdownEditorType]);
```

## Dependencies

`tom_md_editor`, `tom_forge_kit`, `tom_forge_core`, `tom_editors_shared` —
never `tom_forge_shell` (`tom_forge_app/test/platform_layering_test.dart`
PL-8). The Markdown editor brings its preview's webview
(`flutter_inappwebview`), Mermaid (`tom_mermaid_view`) and math
(`flutter_math_fork`). Layer 3 of
`tom_forge/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

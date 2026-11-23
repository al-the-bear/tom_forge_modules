# Tom Forge Dart Editor

Forge's Dart editor adapter. `ForgeDartEditor` makes the Dart code editor
(`tom_dart_editor`) a Forge text editor (`ForgeTextEditor`) over the Forge
kit: document, cursor, selections, decorations, dirty state, the editing
actions, and the Dart editor's analysis plugin (`tom_dart_analysis`): the
summary-backed completions and diagnostics, and the semantic highlighter
(`DartSyntaxHighlighter`) in place of the editor's light one.
`DartOutlineProvider` gives the outline of a Dart editor's code. Where the
editors an application opens read their analysis summaries is
`ForgeDartSummariesByHost`, keyed by the request's host (the panel shell: its
layout controller).

It is a package of its own so an application takes the adapters it uses and
nothing of the others' editors.

## How it reaches the application

The adapter takes a `ForgeKitModule` and, optionally, the `ForgeKitApi` of the
application (`api:`). Without one it asks the module (`forgeKitApiOf`: a
module that implements `ForgeKitApiProvider`, as the panel shell's own module
does). With an API it routes the editing actions and key bindings through it
(`ShellEditorIntegration`), reads its editor settings
(`getEditorSpecificConfig('dart')`) and reports diagnostics; without one the
editor works on its own.

## Registering

The package exports its editor type, the kit's `ForgeKitEditorType`
(`forgeDartEditorType`: `.dart`). An application takes it with the other types
it opens files with; the panel shell:

```dart
final components = ForgeShellComponents(editorTypes: [forgeDartEditorType]);
```

## Dependencies

`tom_dart_editor` and its plugin `tom_dart_analysis`, `tom_forge_kit`,
`tom_forge_core`, `tom_editors_shared` — never `tom_forge_shell`
(`tom_forge_app/test/platform_layering_test.dart` PL-8). The analysis plugin
brings the analyzer (`analyzer`); the editor itself has none. Layer 3 of
`tom_forge/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

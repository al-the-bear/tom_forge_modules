# Editor Component Contract

What an editor component must provide so that it can be assembled into a tool
— embedded on its own, put in the Forge shell, opened by a module, combined
with other editors in an application. The platform layers are in
[platform_architecture.md](platform_architecture.md); this document is the
contract at two of their boundaries: an **editor component** (layer 2) and a
**shell editor** (what the shell and the modules place in a middle split).

`tom_forge_app/test/editor_component_contract_test.dart` checks what can be
checked across the repository; each rule below names its check.

## 1. Editor component (layer 2: `tom_md_editor`, `tom_yaml_editor`, `tom_dart_editor`)

An editor component works without the shell.

| Rule | What it means | Check |
| ---- | ------------- | ----- |
| Controller and widget | A controller owns the document (`MdEditorController`, `YamlEditorController`, `DartCodeController`); the widget renders it. A host creates the controller, keeps it, and gives it to as many widgets as it shows | — |
| Shell-free | The package does not depend on `tom_forge_ui`; the shell wraps the component in an adapter | `platform_layering_test.dart` PL-2 |
| One history per document | Edits go on the controller's `TomUndoStack` (`tom_undo`; text edits as `TextUndoEntry` from `tom_editors_shared`); typing is grouped by `forgeTypingPause`; the text field's own undo is off (`ForgeEditorOwnsUndo`); dirty is measured against a `ForgeSavedMarker` — the history contract, `tom_forge_ui/_copilot_guidelines/editor_history_contract.md` | the conformance runs of its shell editor (§2) |
| Actions by id | The component's actions have `<source>.<action>` ids (`md.toggleBold`, `dart.triggerCompletion`, `yaml.addKey`: the action sets in `tom_editors_shared/lib/src/text_editing/*_editor_actions.dart`); a host learns them as `EditorActionDescriptor`s (`ForgeEditorIntegration.actionDescriptors`) and runs them by id (`executeAction`) | — |
| Integration, not reach-through | A host drives the component through a `ForgeEditorIntegration` (`tom_editors_shared`: text context, action descriptors, `ForgeTextSettings`, text and selection listeners, focus); the standalone integrations are `MdStandaloneIntegration` and `DartStandaloneIntegration` (on `BaseStandaloneIntegration`) and `YamlStandaloneIntegration`, the shell's is `ShellEditorIntegration` | — |
| Settings injected | Font, line height, tab size, word wrap, line numbers and history depth come from `ForgeTextSettings`, not constants | — |
| Debug trail | A `*_trail.dart` file in `lib/src/` with a top-level `bool` switch `k…Debug`, off by default ([debug_mode.md](debug_mode.md)) | EC-4 |
| Runs on the web | `test/web_build_test.dart` compiles the component for the web through `tom_web_build_probe` | EC-4 |
| Embedding documented | `doc/how_to_embed.md`, or a `## Usage` section in the README | EC-4 |

`tom_flow_editor` is the flow editor's placeholder (the package template) and
is exempt until it is built. The shell defines `ForgeVisualEditor` for canvas
editors (element selection, viewport, zoom); no editor implements it yet.

## 2. Shell editor (`ForgeEditor`): a document editor

A **document editor** is a `ForgeEditor` bound to a document: a file, or the
document a tool owns. It answers to the shell through
`tom_forge_shell/lib/src/components/forge_editor.dart`:

- **Routing:** `canHandle(uri)` — accept, inspect (then
  `canHandleContent(uri, bytes)`), or reject.
- **Saving:** `getContent()` is what the shell writes; `markClean()` makes
  the document as it is the saved state (it moves the saved marker and does
  not touch the history); `isDirty` follows the saved state, so undoing back
  to it is clean.
- **Outside changes:** `replaceContent(content)` takes content from outside
  the history (a reload, an external change, a revision restore) in place —
  saved, nothing to undo, shown by every view — or answers false, and the
  shell closes and reopens the editor.
- **Views:** `buildMain` and `buildCopy` show one document with one history;
  the split copy shows every edit, undo and redo of the main view.
- **Actions:** it is the shell's `EditorActionProvider` —
  `supportedActionIds`, `isActionEnabled`, `executeAction`, `capabilities`,
  `stateSnapshot` and `onStateChanged` — so the shell's undo, redo,
  clipboard and line actions reach the active editor.
- **State:** `saveState` / `restoreState` for cursor and scroll
  (`.forge/state/editors/`), optional.

The shell's kinds: `ForgeTextEditor` (a text buffer; the Markdown, Dart and
plain-text adapters), `ForgeSchemaEditor` (structured data with a schema; the
YAML adapter), `ForgeVisualEditor` (canvas; not implemented).

**Every document editor runs the undo conformance harness**
(`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`, `runForgeUndoConformance`): six checks
— dirty follows the saved state, the caret after undo and redo, typing undone
within the pause, no redo after typing, split copies share the history,
replaced content clears it. A check an editor does not meet yet is skipped
with the todo that removes the skip. The register of document editors and
their runs is in the contract test (EC-1, EC-2):

| Document editor | Package | Conformance run |
| --------------- | ------- | --------------- |
| `ForgeMdEditor`, `ForgeDartEditor`, `ForgeYamlEditor`, `ForgePlainTextEditor` | `tom_forge_ui` | `tom_forge_ui/test/undo/adapters_undo_conformance_test.dart` |
| `ForgeMarkdownFileEditor`, `ForgeYamlFileEditor`, `ForgeEnvFileEditor`, `ForgeTodoFileEditor` | `tom_forge_file_editors` | `tom_forge_file_editors/test/undo_conformance_test.dart` |
| `WebsiteConfigEditor` | `tom_website_editor` | `tom_website_editor/test/website_config_editor_undo_conformance_test.dart` |
| `SpecFileEditor` | `tom_specs_editor` | `tom_specs_editor/test/spec_file_editor_undo_conformance_test.dart` |
| `SpecDocumentEditor` | `tom_specs_editor` | covered by `SpecFileEditor`'s run, which adds only the file load, `getContent` and `replaceContent` to it |
| `ForgePdfEditor`, `ForgePdfJsEditor` | `tom_forge_pdf_editors` | `tom_forge_pdf_editors/test/undo_conformance_test.dart` (skips with reasons in its README) |

Test doubles in `tom_forge_ui_testing` (`ForgeTestTextEditor`) are
not part of the register.

## 3. Shell editor: a surface

A **surface** is a component in a middle split that holds no document: a
prompt queue, a prompt trail, a phase overview, a configuration list that
saves its own entries, a view shown as a tab. The shell places only editors
in the middle splits, so a surface is a `ForgeEditor` — and it extends
**`ForgeSurfaceEditor`** (`tom_forge_ui`), which declines every file and is
never dirty. Its URI names it in a scheme of its own (`agent:`, `specs:`,
`forge-view:`); it is no file. A surface has no history to conform to.

| Surface | Package |
| ------- | ------- |
| `PromptQueueEditor`, `PromptTrailEditor` | `tom_forge_agentic` |
| `PhaseSurfaceEditor`, `PhaseOverviewEditor`, `PlaceholderEditor`, `ConfigListEditor`, `ConfigObjectEditor` | `tom_specs_editor` |
| the shell's view-as-tab adapter | `tom_forge_ui` |

EC-1 fails for a `ForgeEditor` that is neither a surface nor in the
register of document editors: a new editor is placed on purpose.

## 4. Assembling editors into a tool

A tool is assembled through the contracts above, never by reaching into an
editor:

- **Standalone:** create the controller, show the widget, drive it through a
  standalone `ForgeEditorIntegration`.
- **In the shell:** a module lists its editors (`ForgeModule.editors`), or
  opens its own documents (`ForgeModule.openUri`) and offers editors for
  Open With (`ForgeModule.editorChoicesFor`); an application lays out
  editors and views (`ForgeApplication`, `PanelLayout`).
- **In an app built on Forge:** `ForgeSuiteExtension` replaces Forge's file
  editor for a kind of file (`fileEditorBuilders`) or offers another beside
  it (`fileEditorAlternatives`) — Webforge's TomSpecs editor for spec files
  is a `SpecFileEditor` offered that way.

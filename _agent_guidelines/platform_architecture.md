# Tom Forge Platform Architecture

Tom Forge is a platform of composable visual editor components: editors that
work on their own, a shell that hosts them, modules that bring editors, views
and actions into the shell, and applications that lay them out. An app is a
composition of these (Tom Forge's own `tom_forge_app`; Webforge, which is Tom
Forge with Webwork added, outside this repository).

This document states the layers, the contract at each boundary and the rules
that keep them apart. `tom_forge_app/test/platform_layering_test.dart` checks
the layering against every package's `pubspec.yaml`; the layer table there
and the one below are the same table.

## 1. Layers

A package depends only on packages of a **lower** layer (its
`dependencies` and `dev_dependencies` alike), with one exception: any package
may take a test-support package as a dev_dependency. Harness packages depend
on anything below the apps, and nothing depends on them.

| Layer | Packages | What it is |
| ----- | -------- | ---------- |
| 0 Foundation | `tom_forge_core`, `tom_website_editor_core`, `tom_dart_editor_bundler`, `tom_web_build_probe` | Pure Dart, no Flutter: the types and service contracts (`tom_forge_core`), the website model, the Dart editor's summary bundler tool, the web-compile probe the editor packages use in their tests |
| 1 Editor kit and shared look | `tom_editors_shared`, `tom_mermaid_view`, `tom_forge_shared_ui` | Widgets and utilities every editor builds on: the text editor core, `TextUndoEntry` on `tom_undo`'s stack, the typing pause, and — re-exported from `tom_ai/modules/tom_ui_controls` — the tree view, validation markers, split panels, search box and inline controls (`tom_editors_shared`, no webview); Mermaid diagrams in a webview with the bundled mermaid.js (`tom_mermaid_view`, taken only where diagrams are rendered); the look the shell and the applications beside it share — `ForgeShellTheme`, `forgeThemeData`, `ForgeDimensions`, `ForgeAnimations`, the action bar (`ForgeActionBar`), the status bar (`ForgeStatusBar`, `ForgeStatusItem`), the input box, quick pick, error recovery dialog and focus indicator, the notification toasts and history, the context menu rendering — on Flutter, `tom_ui_support` and `tom_forge_core` only (`tom_forge_shared_ui`, re-exported by the shell core; Webwork takes it without the shell, PL-6) |
| 2 Editors | `tom_md_editor`, `tom_yaml_editor`, `tom_dart_editor`, `tom_flow_editor` | The editor components, each usable without the shell (`tom_dart_editor/doc/how_to_embed.md`, `tom_yaml_editor/doc/how_to_embed.md`) |
| 3 Shell core | `tom_forge_shell` | The panel shell, `ForgeShellApi`, the component, editor, view, module and application contracts, the default services, the scaffold and its widgets, the built-in views and the plain-text editor; no terminal, no code editor, no keychain, no native file dialog and no `dart:io`, so it builds for the web. What a shell is assembled from beyond that comes in as `ForgeShellComponents` (terminal manager and view, secret storage, editor types, file pickers, host environment) |
| 4 Shell parts | `tom_forge_terminal`, `tom_forge_code_editors`, `tom_forge_platform_secrets`, `tom_forge_desktop_host` | The parts that plug into the core: PTY and process terminals with the terminal view (`flutter_pty`, the `xterm` fork); the adapters that make the layer-2 Markdown, Dart and YAML editors shell editors, as editor types; secrets in the platform keychain (`flutter_secure_storage`); the desktop host — the native file dialogs (`file_picker`, `file_selector`), the machine's shells and folders, the workspace folder above a picked folder and `.forge/` kept out of git (`dart:io`) |
| 4 Test support | `tom_forge_ui_testing` | The undo conformance harness and the shell's test doubles, built on `flutter_test` and the shell core; any package may take it as a dev_dependency, the shell's own suites included, so no product links the test framework |
| 5 Shell umbrella | `tom_forge_ui` | The core with its parts as one library, and `useForgeDesktopComponents()` / `forgeDesktopComponents`, which register or hand a shell the terminal, the code editors and the keychain |
| 6 Shell services | `tom_forge_agentic` | The agent and chat UI for any module to use: the Forge chat module, the chat view and the prompt queue and trail editors, over the composer, queue, trail, connection, send and change-log views and controllers of `tom_ai/modules/tom_agentic_ui` (which needs no shell and is re-exported) |
| 7 Modules | `tom_forge_file_editors`, `tom_forge_office_editors`, `tom_forge_pdf_editors`, `tom_forge_quests`, `tom_website_editor`, `tom_specs_editor` | Feature modules: each a `ForgeModule` with its editors, views, actions and applications (`tom_specs_editor` is also an app of its own) |
| 8 Module test support | `tom_forge_file_editors_testing`, `tom_forge_office_editors_testing`, `tom_forge_pdf_editors_testing` | Each module's undo conformance subjects (how to drive its editors through the harness), for the module's own suite and an app's; taken only as dev_dependencies |
| 9 Apps | `tom_forge_app` | Composition: `composeForgeSuite`, and Tom Forge's `main` |
| Harness | `tom_dart_editor_test`, `tom_flow_editor_test`, `tom_forge_ui_test`, `tom_md_editor_test`, `tom_yaml_editor_test`, `tom_wpe_webview_test` | Companion apps and test beds |

What the layering buys:

- **An editor never knows the shell.** Layer 2 cannot import the shell,
  so every editor embeds in any Flutter app; the shell wraps it in an adapter
  (`ForgeMdEditor`, `ForgeYamlEditor`, `ForgeDartEditor` in
  `tom_forge_code_editors`).
- **The shell core needs neither a terminal nor the editors nor the desktop.**
  `tom_forge_shell` builds without `flutter_pty`, `xterm`, the layer-2 editors,
  `flutter_secure_storage`, the file-picker plugins and `dart:io` — for the web
  too: without its parts it has no terminals, keeps secrets in memory, opens
  files as plain text and picks no files or folders. An app hands a shell its
  parts (`components: forgeDesktopComponents`) or registers them once
  (`useForgeDesktopComponents()`, also what a test package's
  `flutter_test_config.dart` does).
- **The contracts are below the UI.** `tom_forge_core` holds the service
  contracts (clipboard, configuration, diagnostics, notifications, output,
  search, secrets, terminals, undo, virtual documents) and pure-Dart
  defaults, so a headless tool or a test uses them without Flutter.
- **A module is added, not wired in.** Layer 7 depends on the shell, never the
  shell on a module; an app decides which modules it composes.

`tom_flow_editor` is a placeholder (the package template, unpublished): the
flow editor is not built; the process editor and the prompt template editor
take its place in the quest workbench for now.

## 2. Boundaries and their contracts

### 2.1 Component → shell: `ForgeComponent`, `ForgeEditor`, `ForgeView`

`tom_forge_shell/lib/src/components/`. A component is what the shell shows in a
panel. A `ForgeEditor` is bound to a document URI and

- answers whether it opens a file — `canHandle(uri)` (accept, inspect,
  reject), and for inspect `canHandleContent(uri, bytes)`;
- reports dirty against the saved state (`isDirty`, `markClean`) and replaces
  its content in place when the file changed elsewhere (`replaceContent`);
- gives the shell its content to save (`getContent`) and its view state
  (`saveState` / `restoreState`, kept in `.forge/state/editors/`);
- implements `EditorActionProvider`, so the shell routes cut, copy, paste,
  undo and redo to the active editor.

The full contract an editor meets, and the register of document editors and
surfaces, is [editor_component_contract.md](editor_component_contract.md). A
component in a middle split that holds no document is a surface
(`ForgeSurfaceEditor`). Every document editor keeps one history per document
under the history contract
(`tom_forge_ui/_agent_guidelines/editor_history_contract.md`); the
conformance harness in `package:tom_forge_ui_testing/tom_forge_ui_testing.dart` checks it.

### 2.2 Module → shell: `ForgeModule`

`tom_forge_shell/lib/src/module/forge_module.dart`. A module contributes
editors, views, actions, shortcuts, context-menu contributions
(`context_menu_contributions.md`), shortcut menus, status-bar items and
settings panels. In `activate(shell)` it receives the `ForgeShellApi` — the
only door into the shell: layout, applications, file system, modules,
configuration, storage, undo, dialogs, notifications and the other managers.

### 2.3 Opening a file

The shell's layout controller (`DefaultLayoutController`) decides which
editor opens a file, in this order:

1. **A module that owns the document** — `ForgeModule.openUri`, asked before
   the file is read as text (a directory bundle, an encrypted container).
2. **A module editor that accepts the URI** — `canHandle` accept; then the
   editors that asked to inspect, by content.
3. **The user's default editor for the extension** (settings), else the
   shell's built-in editor for `.md`, `.dart`, `.yaml` / `.yml`, else plain
   text.

In an app composed by `composeForgeSuite`, the file editors module
(`tom_forge_file_editors`) takes most files in step 1: it is registered after
every other module, so it is asked last, and it opens a file over a
`ForgeFileSession` in the editor of its kind unless another module's editor
accepts the file, the file is Dart, or the user gave its extension a default
editor; those go on to steps 2 and 3. The PDF editors module (`tom_forge_pdf_editors`)
is registered before the extensions' modules and takes every `.pdf`, which the
file editors therefore leave alone. **Open With** offers every module's
choices for a file (`ForgeModule.editorChoicesFor`) and the open editors that
accept it.

### 2.4 Application → shell: `ForgeApplication`

`tom_forge_shell/lib/src/model/forge_application.dart`. An application is a
title, an icon and a layout — `PanelLayout` (side, bottom and middle panels)
or `FullScreenLayout` (one view) — switched to through the application
switcher. Static applications are added on every start; a restorable one is
made by the factory of its kind and recreated at the next start. Layouts are
kept per application in `.forge/state/apps`. Quitting asks every application
first (`ForgeApplicationRegistry.quit`).

### 2.5 App → suite: `composeForgeSuite` and `ForgeSuiteExtension`

`tom_forge_app/lib/src/forge_suite.dart`. `composeForgeSuite` puts Tom Forge
on a shell: the shell module, the app module, the website editor module and
the quests module, the tom_forge application, each extension's modules, the
file editors module, then each extension's applications, and restores the
applications open at the last exit. A host adds to Tom Forge only through
`ForgeSuiteExtension`: modules, applications, file-editor builders that
replace Forge's editor for a kind of file, and file-editor alternatives for
Open With. Webforge (`app_webwork/tom_webwork_webforge`) is such a host.

### 2.6 Storage: `TomFileSystem`

The shell's file access is `tom_file_system`'s `TomFileSystem`
(`ForgeShellApi.fileSystem`): the explorer, the layout controller's open and
the scaffold's save, the file editors and their `ForgeFileSession`s
(`tom_file_session`), the workspace search (`DefaultSearchManager`), quick
open and its `.gitignore` rules (`forgeLoadGitignores`), the `.forge/` state
(`DefaultWorkspaceStateManager`) and module storage
(`PersistentModuleStorage`), and the Markdown editor's file provider and
file follower all read and write through it, so they run on the local disk,
in memory in a test and on the web. So does the TomSpecs editor: its review
file and editor preferences (`ReviewStore`, `EditorPreferencesStore`), its
`*.docspecs.yaml` documents and their session sidecars, the files a prompt
injects (`SpecPromptComposer`), the raw config files it opens
(`RawFileModule`), and the agent sidecars its config editors and chat edit —
`tom_core_agentic`'s stores (profiles, templates, chat variables, queue, timed
requests, agent settings, trail, bridge choice, session id), each an
`AgentSidecarStore` over the workspace's file system. An app gives one
`TomLocalFileSystem` of the workspace to the shell and to its state.

`dart:io` stays where a platform service needs it, each in its own place:

| Platform service | Where | Why |
| ---------------- | ----- | --- |
| Terminals | `tom_forge_terminal` `pty_terminal.dart`, `default_terminal_manager.dart` | processes and pseudo-terminals |
| Finding the workspace folder above a picked folder; keeping `.forge/` out of git | `tom_forge_desktop_host` `forge_host_workspace.dart` | host folders before a file system exists; runs git |
| Native file and folder dialogs | `tom_forge_desktop_host` `desktop_host.dart` (`DesktopFilePickers`), `workspace_folder_selector.dart`; the core reaches them through `ForgeFilePickers` (Open Folder, Open File, Save As, the configuration's folder and tool paths) | a local folder is chosen by nature |
| Shell detection and the central configuration folder | `tom_forge_desktop_host` `desktop_host.dart` (`DesktopHostEnvironment`), reached through `ForgeHostEnvironment` from the configuration dialog | installed shells; a host folder outside the workspace, picked natively |
| Local images in the Markdown preview | `tom_md_editor` `local_file_image_io.dart` (conditional import) | Flutter's own file image providers |
| The comment author | `tom_md_editor` `md_local_author.dart` | the OS user |
| The website's dev server and preview | `tom_website_editor` `website_process_runner.dart`, `website_preview_*` | processes, the platform's browser |
| Test workspaces | `tom_forge_ui_testing` `test_workspace.dart` | test support on a real disk |
| The TomSpecs editor's workspace and environment | `tom_specs_editor` `main.dart` | the process's working folder becomes the workspace's `TomLocalFileSystem`; its environment moves the review, preferences and agent sidecar files |
| The native vector library of the agent memory | `tom_specs_editor` `spec_memory_plane.dart` (`_findSqliteVecRoot`) | locates the `sqlite_vec` binary on the host |
| The spec engine's file boundary | `tom_specs_editor` `agent_tools_module.dart` | `tom_spec_engine`'s `SpecFileFacade`, memory plane and script runner take the workspace as a folder on disk (the app passes its workspace's) |

### 2.7 The quest workbench

`tom_forge_quests` opens one quest application per open quest (at most one
per quest) and the Open Quest picker. Today it provides the applications'
frame (`spec_quest_workbench.tom_forge.md`, part one). The quest
applications driving the shared quest runtime — the VS Code extension's
engine as a TypeScript process, one per open quest, over its protocol — is
part two of that specification (todo `qavs_wwworkbench-1`); the runtime
client then sits in layer 4 or 5, never in the shell.

## 3. Rules

- **Dependencies point down the layer table.** A new package gets a row in
  the table above and in the layering test, which fails for a package it
  does not know.
- **Licence:** every package here is BSD-3-Clause. Forge links no copyleft:
  nothing in Forge depends on Webwork (an application on Forge, never a
  dependency of it); the shared UI Forge uses is the BSD-3 Tom UI modules
  in `tom_ai/modules` (`tom_file_editors`, `tom_todo_ui`, `tom_ui_testing`). The licence audit of the resolved graph
  (`tom_forge_app/test/qim_none1_licence_audit_test.dart`) checks the rest.
- **Base first:** behaviour another `tom_*` library owns (the file system,
  undo, `.gitignore` rules in `tom_basics`, agent models in
  `tom_core_agentic`) is added there and consumed here.
- **Debug mode in every editor component** — `debug_mode.md`.
- **Context menus through contributions**, never a hard-coded `showMenu` —
  `context_menu_contributions.md`.

## 4. Where the detail is

| Topic | Document |
| ----- | -------- |
| Workspace files and their formats | [configuration_compatibility.md](configuration_compatibility.md) |
| How combined components behave as one tool | [integrated_ux_patterns.md](integrated_ux_patterns.md) |
| What an editor provides | [editor_component_contract.md](editor_component_contract.md) |
| Panel shell concept and specification | `tom_forge_ui/doc/forge_panel_shell_concept.md`, `forge_panel_shell_spec.md` |
| Editor base and component API | `tom_forge_ui/doc/forge_editor_base.md` |
| Editing actions through the active editor | `tom_forge_ui/doc/editor_action_externalization.md`, the workspace's `global_actions_coordination.md` |
| History and undo | `tom_forge_ui/_agent_guidelines/editor_history_contract.md` |
| Feature coverage against VS Code | `tom_forge_ui/doc/forge_vs_code_api_comparison.md`, `forge_feature_checklist.md` |
| Embedding an editor | `how_to_embed.md` in `tom_dart_editor/doc`, `tom_yaml_editor/doc` |
| Summary scopes of the Dart editor | `tom_dart_editor/doc/summary_scopes.md` |
| The quest workbench | `_ai/quests/tom_forge/spec_quest_workbench.tom_forge.md` |

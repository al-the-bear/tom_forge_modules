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

A package depends only on packages of a **lower** layer (its `dependencies`
and `dev_dependencies` alike), with three exceptions: any package may take a
test-support package as a dev_dependency (an editor adapter too: its runtime
dependencies stay its editor with the editor's plugin packages, the kit and
the light shared packages, PL-8); within layer 3 an editor adapter may take
the shared look (`ForgeSessionFileFrame`), never the other way (PL-2); and
within layer 2 a component's plugin packages take their component, never the
other way (PL-2: the Markdown editor's `tom_md_mermaid`, `tom_md_math`,
`tom_md_docspecs`, `tom_md_review` and `tom_md_http` take `tom_md_editor`).
Harness packages depend on anything below the apps, and nothing depends on
them.

| Layer | Packages | What it is |
| ----- | -------- | ---------- |
| 0 Foundation | `tom_forge_core`, `tom_website_editor_core`, `tom_dart_editor_bundler`, `tom_web_build_probe` | Pure Dart, no Flutter: the types and service contracts (`tom_forge_core`), the website model, the Dart editor's summary bundler tool, the web-compile probe the editor packages use in their tests |
| 1 Editor kit | `tom_editors_shared` | Widgets and utilities every editor builds on: the text editor core, `TextUndoEntry` on `tom_undo`'s stack, the typing pause, and — re-exported from `tom_ai/modules/tom_ui_controls` — the tree view, validation markers, split panels, search box and inline controls (no webview) |
| 2 Editors and the Forge kit | `tom_md_editor` with its plugin packages `tom_md_mermaid`, `tom_md_math`, `tom_md_docspecs`, `tom_md_review`, `tom_md_http`; `tom_yaml_editor`, `tom_dart_editor`, `tom_flow_editor`, `tom_forge_kit` | The editor components, each usable without the shell (`tom_dart_editor/doc/how_to_embed.md`, `tom_yaml_editor/doc/how_to_embed.md`, `tom_md_editor/doc/how_to_embed.md`); the Markdown editor's heavy features as plugin packages it does not depend on (R4): Mermaid diagrams (`tom_mermaid_view`, a webview), LaTeX math (`flutter_math_fork`), DocSpecs schemas (`tom_doc_specs`, `tom_doc_scanner`), reviews (`tom_som_dart_runtime`) and documents on a web server (`http`), each with one entry point (`mdMermaidPlugin()`, `mdMathPlugin()`, `controller.setSchema(...)`, the `MdReviewEditing` extension, `HttpDocumentProvider`); the Forge kit, layout-free and without widgets of its own: the component, editor and module contracts, actions and shortcuts, the routing of undo, redo, clipboard, find and save to the active editor, autosave, dialogs, outline, workspace state, decorations, the context menu controller, the host ports, `ForgeKitApi` (what a component sees), `ForgeEditorHost` (every placement of an editor is asked of the application), `ForgeStateStore` (preferences and workspace state as keyed documents the host may supply), and the file kinds a module opens files with over a `ForgeFileSession` (`ForgeKitFileKind` in a `ForgeFileKindRegistry` the application fills; `ForgeSessionFile` binds an editor's controller to the session), so any application layout builds on it (`tom_forge_kit/README.md`) |
| 3 Shared look and editor adapters | `tom_forge_shared_ui`, `tom_forge_md_editor`, `tom_forge_dart_editor`, `tom_forge_yaml_editor` | One rendering of the Forge kit's models, without a layout: the tokens (`ForgeShellTheme`, `forgeThemeData`, `ForgeDimensions`, `ForgeAnimations`) and the elements, each drawing a kit model and acting through `ForgeKitApi` — the action bar (`ForgeKitActionBar` over a `ForgeActionBarModel`), the status bar (`ForgeKitStatusBar` over `ForgeKitStatusItem`s), menus (`ForgeMenuButton` over a `ForgeMenuModel`), the command list (`ForgeCommandList` over a `ForgeCommandListModel`), the context menu (`ForgeContextMenuPresenter` over the kit's `ForgeContextMenuController`), the quick pick and input box of the kit's dialog manager (`ForgeDialogPresenter`, `ForgeDialogLayer`), the notification toasts and history (`ForgeNotificationLayer`), the focus indicator (`ForgeFocusIndicator.kit`), the error recovery dialog, `ForgeEditorSurface`, which shows any `ForgeEditor` connected to the kit (its state, its keys, undo, redo, the clipboard and find), and `ForgeSessionFileFrame`, the state of a session-backed file above its editor. On Flutter, `tom_ui_support`, `tom_forge_core`, `tom_forge_kit` and `tom_file_session_ui` (the session file's binding and frame, one implementation with `tom_file_editors`) only (PL-6): an application uses an element, draws the model itself, or leaves it out; the shell core re-exports it, Webwork takes it without the shell. The editor adapters make the layer-2 Markdown, Dart and YAML editors Forge editors over the kit (`ForgeMdEditor`, `ForgeDartEditor`, `ForgeYamlEditor`, each reaching the application through `ForgeKitApi`) and export their editor types (`forgeMarkdownEditorType`, `forgeDartEditorType`, `forgeYamlEditorType`, the kit's `ForgeKitEditorType`), which an application takes to open files by extension; the Markdown and YAML adapters also export their file kinds (`forgeMarkdownFileKind` with `ForgeMarkdownFileEditor`, `forgeYamlFileKind` with `ForgeYamlFileEditor`), which an application registers with its file module — importing an adapter registers nothing; each takes its editor (the Markdown adapter with the editor's plugin packages it runs with: Mermaid, math, DocSpecs and reviews), the kit and light shared packages only, never the shell (PL-8), so the YAML adapter brings no analyzer, webview or Mermaid |
| 4 Shell core | `tom_forge_shell` | The panel shell, an application of the kit: `ForgeShellApi` (`ForgeKitApi` plus the panel layout), `ForgeModule` (the kit's module contract plus the shell's extras), the application contracts, `ForgeEditorHost` with tabs, the layout, the scaffold and its widgets, the built-in views and the plain-text editor; no terminal, no code editor, no keychain, no native file dialog and no `dart:io`, so it builds for the web. What a shell is assembled from beyond that comes in as `ForgeShellComponents` (terminal manager and view, secret storage, editor types, file pickers, host environment) |
| 5 Shell parts | `tom_forge_terminal`, `tom_forge_code_editors`, `tom_forge_platform_secrets`, `tom_forge_desktop_host` | The parts that plug into the core: PTY and process terminals with the terminal view (`flutter_pty`, the `xterm` fork); for one release, the three editor adapters re-exported with the shell-typed helpers they had (`forgeCodeEditorComponents`, `DefaultLayoutController.dartSummaryAssets`, `registerMdEditor` and its twins on the shell's module); secrets in the platform keychain (`flutter_secure_storage`); the desktop host — the native file dialogs (`file_picker`, `file_selector`), the machine's shells and folders, the workspace folder above a picked folder and `.forge/` kept out of git (`dart:io`) |
| 5 Test support | `tom_forge_ui_testing` | The undo conformance harness and the shell's test doubles, built on `flutter_test` and the shell core; any package may take it as a dev_dependency, the shell's own suites included, so no product links the test framework |
| 6 Shell umbrella | `tom_forge_ui` | The core with its parts as one library, and `useForgeDesktopComponents()` / `forgeDesktopComponents`, which register or hand a shell the terminal, the code editors, the keychain and the desktop host — the full desktop for consumers outside this repository (Webwork); no package in `tom_forge` takes it (PL-7) |
| 7 Shell services | `tom_forge_agentic` | The agent and chat UI for any module to use: the Forge chat module (a `ForgeKitModule`: it takes the kit, not the shell), the chat view and the prompt queue and trail editors, over the composer, queue, trail, connection, send and change-log views and controllers of `tom_ai/modules/tom_agentic_ui` (which needs no shell and is re-exported) |
| 8 Modules | `tom_forge_file_editors`, `tom_forge_office_editors`, `tom_forge_pdf_editors`, `tom_forge_quests`, `tom_website_editor`, `tom_specs_editor` | Feature modules: each a module with its editors, views, actions and applications (`tom_specs_editor` is also an app of its own). Each takes the kit, the editor adapters and shell parts it uses and the shell only for what its pubspec names that the kit does not have — then it is a `ForgeModule`; never the umbrella. `tom_forge_file_editors` keeps the `.env`, todo-file and plain-text editors and takes no editor adapter: the Markdown and YAML kinds reach it only from the registry the application fills (PL-9), so an application that wants `.env` files takes no webview and no math library |
| 9 Module and adapter test support | `tom_forge_file_editors_testing`, `tom_forge_md_editor_testing`, `tom_forge_yaml_editor_testing`, `tom_forge_office_editors_testing`, `tom_forge_pdf_editors_testing` | Each module's undo conformance subjects (how to drive its editors through the harness), and the Markdown and YAML file kinds' (`ForgeMarkdownFileSubject`, `ForgeYamlFileSubject`), for the package's own suite and an app's; above the harness they build on, taken only as dev_dependencies |
| 10 Apps | `tom_forge_app` | Composition: `composeForgeSuite`, and Tom Forge's `main` |
| Harness | `tom_dart_editor_test`, `tom_flow_editor_test`, `tom_forge_ui_test`, `tom_md_editor_test`, `tom_yaml_editor_test`, `tom_wpe_webview_test` | Companion apps and test beds |

What the layering buys:

- **An editor never knows the shell.** Layer 2 cannot import the shell,
  so every editor embeds in any Flutter app; an adapter on the kit makes it a
  Forge editor (`ForgeMdEditor` in `tom_forge_md_editor`, `ForgeYamlEditor`
  in `tom_forge_yaml_editor`, `ForgeDartEditor` in `tom_forge_dart_editor`),
  and an application takes only the adapters it uses.
- **One look, any layout.** `tom_forge_shared_ui` draws the kit's models
  and imposes no layout: an application places the elements it wants, draws
  a model its own way, or leaves an element out; the kit never depends on
  it.
- **Any layout builds on the kit.** `tom_forge_kit` names no panel, tab or
  window: an application decides where an editor appears through
  `ForgeEditorHost`, and keeps its state where it decides through
  `ForgeStateStore` (Webwork keeps it in its own device settings and in
  IndexedDB). The panel shell is one application of it; it re-exports the kit
  for one release so its consumers keep compiling.
- **The shell core needs neither a terminal nor the editors nor the desktop.**
  `tom_forge_shell` builds without `flutter_pty`, `xterm`, the layer-2 editors,
  `flutter_secure_storage`, the file-picker plugins and `dart:io` — for the web
  too: without its parts it has no terminals, keeps secrets in memory, opens
  files as plain text and picks no files or folders. An app hands a shell its
  parts (`components:`, the parts' `forgeTerminalComponents`, the adapters'
  editor types as `ForgeShellComponents(editorTypes: [...])`,
  `forgePlatformSecretComponents` and `forgeDesktopHostComponents` merged
  with `mergedWith`) or registers them
  once (`ForgeShellComponents.register`, also what a test package's
  `flutter_test_config.dart` does); an app outside this repository takes the
  umbrella's `forgeDesktopComponents` / `useForgeDesktopComponents()`.
- **The contracts are below the UI.** `tom_forge_core` holds the service
  contracts (clipboard, configuration, diagnostics, notifications, output,
  search, secrets, terminals, undo, virtual documents) and pure-Dart
  defaults, so a headless tool or a test uses them without Flutter.
- **A module is added, not wired in.** Layer 8 depends on the kit (and on
  the shell for what is the panel shell's), never the shell on a module; an
  app decides which modules it composes.

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

### 2.2 Module → shell: `ForgeKitModule`, `ForgeModule`

`tom_forge_kit/lib/src/module/forge_kit_module.dart` and
`tom_forge_shell/lib/src/module/forge_module.dart`. A module contributes
editors, views, actions, shortcuts, context-menu contributions
(`context_menu_contributions.md`), shortcut menus, status-bar items and
settings panels.

- A **`ForgeKitModule`** needs nothing of a host beyond the kit: in
  `activate(api)` it receives a `ForgeKitApi`, places its editors through the
  editor host (`ForgeEditorHost`, with a layout-free placement hint) and hands
  what an application offers beyond the contract over as `ForgeModuleExtra`s.
  The panel shell registers it as it registers a `ForgeModule`
  (`DefaultShellApi.registerModule` activates it with the `ForgeShellApi`),
  takes its editors, views, actions, context menus, `openUri` and Open With
  choices, and reads its extras; of the extras the shell reads, a kit-only
  module can offer only the kit's `ForgeKitStatusItemsExtra` (status items):
  the settings sections (`ForgeConfigPanel`) and external tools are the
  shell's types.
- A **`ForgeModule`** is the kit's contract plus the panel shell's: in
  `activate(shell)` it receives the `ForgeShellApi` — layout, applications,
  file system, modules, configuration, storage, undo, dialogs, notifications
  and the other managers — and it brings status-bar items, settings sections
  and external tools.

### 2.3 Opening a file

The shell's layout controller (`DefaultLayoutController`) decides which
editor opens a file, in this order:

1. **A module that owns the document** — `ForgeModule.openUri` (a
   `ForgeKitModule`'s `openUri`), asked before the file is read as text (a
   directory bundle, an encrypted container).
2. **A module editor that accepts the URI** — `canHandle` accept; then the
   editors that asked to inspect, by content.
3. **The user's default editor for the extension** (settings), else the
   editor type the shell was given for it (the adapters' types for `.md` /
   `.markdown`, `.dart`, `.yaml` / `.yml`), else plain text.

In an app composed by `composeForgeSuite`, the file editors module
(`tom_forge_file_editors`) takes most files in step 1: it is registered after
every other module, so it is asked last, and it opens a file over a
`ForgeFileSession` in the editor of its kind — `.env` and todo files its own,
then the kinds the suite registered with it (`forgeSuiteFileKinds`: the
Markdown and YAML adapters' file kinds), then plain text — unless another module's editor
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
file editors module (with the file kinds of `forgeSuiteFileKinds`), then each
extension's applications, and restores the
applications open at the last exit. A host adds to Tom Forge only through
`ForgeSuiteExtension`: modules, applications, file-editor builders that
replace Forge's editor for a kind of file (keyed by the kind's id), and file-editor alternatives for
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
client then sits in layer 5 or 6, never in the shell.

## 3. Rules

- **Dependencies point down the layer table.** A new package gets a row in
  the table above and in the layering test, which fails for a package it
  does not know.
- **A module takes the kit and the parts it uses, never the umbrella.**
  `tom_forge_ui` is the full desktop for consumers outside this repository;
  no package in `tom_forge` depends on it or imports it (PL-7), test support
  and harness packages included. A module depends on `tom_forge_kit`, on
  `tom_forge_shared_ui` when it shows the kit's UI elements, and on an editor
  adapter or a shell part only when it uses it (`tom_forge_md_editor`,
  `tom_forge_yaml_editor`, `tom_forge_dart_editor`, `tom_forge_terminal`,
  `tom_forge_platform_secrets`, `tom_forge_desktop_host`), each with a pubspec
  comment why. **A module
  whose use of the shell would be only registration or editor placement is a
  `ForgeKitModule` and does not take `tom_forge_shell`**: the panel shell's
  registry takes a kit module, and `ForgeEditorHost` places editors with a
  placement hint the shell maps to a middle panel. It takes
  `tom_forge_shell` only for what the kit does not have — the applications
  and their panel layouts, the window focus, the host environment, the file
  pickers, settings sections, external tools, the plain-text editor and the
  shell's own module — and is
  then a `ForgeModule`; its pubspec comment names exactly those, and it
  imports the shell with a `show` list of them and the kit for the rest. What
  a module needs beyond `ForgeKitApi` without a shell goes through the module
  contract's hooks (`ForgeModuleExtra`).
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

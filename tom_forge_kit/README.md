# Tom Forge Kit

The layout-free part of Forge: what a component sees and what a module
contributes, with **no widgets and no layout of its own**. An application
places its editors as it decides; the panel shell (`tom_forge_shell`) is one
such application and is built on this package.

## The layers

| Layer | Package | What it holds |
| --- | --- | --- |
| Core | `tom_forge_core` | Service contracts and their defaults (output, diagnostics, configuration, notifications, progress, search, undo), events, diagnostics |
| **Kit** | `tom_forge_kit` | Components, editors and modules; actions, shortcuts, context-menu entries and status items as data; the kit API, the editor host port, the state-store port; the default services |
| Look | `tom_forge_shared_ui` | Theme tokens and one rendering of the kit's models (no layout); an application may draw them itself |
| Panel shell | `tom_forge_shell` | The scaffold, panels, editor tabs, menus, palette, configuration, views; re-exports the kit |

## `ForgeKitApi`

The API a component sees, handed to a module in `ForgeKitModule.activate`:
the observable `state` (`ForgeKitState`: focus, open and active editors,
unsaved work, diagnostics), the services (`fileSystem`, `output`,
`diagnostics`, `config`, `notifications`, `progress`, `dialogs`, `clipboard`,
`storage`, `undoManager`, `fileDecorations`, `outline`, `search`,
`actionRegistry`, `shortcuts`, `workspaceState`, `contextMenus`), the actions
(`executeAction`, `isActionEnabled`, `undo`, `redo`), the editor settings, and
`openFile`, which asks the modules first (`ForgeKitModule.openUri`) and then
the editor host.

`DefaultKitApi` is the API of a host that is not the panel shell: the default
services around the host's editor host, state store and file system, with a
`DefaultKitState` the host feeds (editors shown, closed, focused).

## `ForgeEditorHost`

Where editors appear is the application's decision, never the kit's. The kit
asks through this port: `showEditor`, `closeEditor`, `bringToFront`, and
`openEditorFor(uri)`, with which the application chooses the editor for a
resource and where it goes. The panel shell implements it with its editor tabs
(`ForgeTabEditorHost`).

`showEditor`, `openEditorFor` and `ForgeKitApi.openFile` take a placement
hint (`placement:`): an opaque value the application recorded or understands
— the `placement` a `ForgeNavigationLocation` carries is one — which the kit
passes through unread (`DefaultKitApi.openFile` hands it to `openEditorFor`).
The application interprets it (the panel shell: the index of a middle panel)
and places the editor as it decides when it is null or one it does not
understand. It names no panel, tab or window.

## Editor types

`ForgeKitEditorType` is one kind of editor an application opens files with by
extension: an id (what the editor answers as `ForgeEditorOfType.editorTypeId`),
a name and description for **Open With**, the extensions it opens by default,
and a factory taking a `ForgeKitEditorRequest` — the file, its content, the
module, the application's `ForgeKitApi`, its file system and an opaque `host`
value (the panel shell: its layout controller). It names no panel, tab or
window. The editor adapters export theirs (`forgeMarkdownEditorType` in
`tom_forge_md_editor`, `forgeDartEditorType` in `tom_forge_dart_editor`,
`forgeYamlEditorType` in `tom_forge_yaml_editor`); the panel shell takes them
through `ForgeShellComponents.editorTypes`.

## File kinds

`ForgeKitFileKind` is one kind of file a module opens over a
`ForgeFileSession` (`tom_file_session`, re-exported): an id (the **Open With**
choice's, the key a host's replacement editor is given under), a label and an
icon for **Open With**, the file extensions it takes and a factory taking a
`ForgeFileKindRequest` — the session, the module and the application's
`ForgeKitApi`. The application keeps the kinds it takes in a
`ForgeFileKindRegistry` (asked in order, the first match taking the file; a
kind registered again under its id replaces the old one in place) and hands it
to its file module; nothing registers itself on import. The Markdown and YAML
adapters export theirs (`forgeMarkdownFileKind`, `forgeYamlFileKind`).

`ForgeSessionFile` binds an editor's controller, which keeps the one history,
to its session, which carries the bytes (the kit re-exports it from
`tom_file_session_ui`, the one implementation `tom_file_editors` uses too): loaded once, `\n` line endings in the
editor and CRLF kept on save, a save that checks the disk first (`canSave`,
`save`, `keepMine`, `takeTheirs`, `replaceWith`). `tom_forge_shared_ui`'s
`ForgeSessionFileFrame` draws its state.

An editor reaches the application through the API it is given, or the one its
module was activated with: `forgeKitApiOf(module)` answers it for a module
that implements `ForgeKitApiProvider` (the panel shell's own module does).

## `ForgeStateStore`

Keyed documents the host persists — the workspace state, the layouts an
application keeps, the preferences — through one interface the host
implements: `read`, `write` (atomic per key, `null` removes), `keys` and
`flushed`. The kit brings three:

| Store | For | Keys and values |
| --- | --- | --- |
| `ForgeMemoryStateStore` | tests, hosts that persist elsewhere (`initial:`, `snapshot()`) | any key; documents copied as JSON |
| `ForgeSharedPreferencesStateStore` | the preferences (default) | the `forge.*` shared_preferences keys, each value encoded as before (bool, int, double, String, `List<String>` natively; maps and other lists as JSON text) |
| `ForgeFileStateStore` | the workspace state (default) | the path under the workspace's `.forge/`; `.json` keys as two-space-indented JSON, other keys as text; atomic writes in order per file |

`ForgeKitPreferences` (and the panel shell's `ForgePreferencesService`) and
`DefaultWorkspaceStateManager` read and write only through a store, under one
rule: **written once per gesture, never before the start's restore**. The
writes of one key within a microtask become one store write of the last value
(`ForgeCoalescedStateWriter`), and nothing is written until `load()` /
`initialize()` has finished; a value set before that stays in memory only and
is dropped by the restore. `DefaultKitApi` puts the preferences and the
workspace state in the store the host gives it (`restore()` at the start,
`flushed()` to wait for the writes).

The kit runs on the web, iOS, Android and the desktop: nothing in it imports
`dart:io`. `example/` is a minimal application over `DefaultKitApi` that is
built for all four.

## What an element draws

Every UI element is a model here and a widget elsewhere: the kit says what
an element shows, `tom_forge_shared_ui` draws it one way, and an application
may draw it its own way or leave it out. The models are pure data, read from
the kit at the moment they are built:

| Model | What it holds |
| --- | --- |
| `ForgeActionState` | One action as an element shows it: label, icon, bound key (`⌘C`), group, whether it can run (`forgeActionEnabled`: a standard editing action by the active editor's state snapshot, any other by its own `isEnabled`) and whether it is shown |
| `ForgeActionBarModel` | Which actions a bar shows: `ForgeActionBarSection`s of action ids; `resolve(api)` gives their states, unknown and invisible ones left out |
| `ForgeMenuModel` | The visible actions of one `ForgeMenuLocation` (File, Edit, ...) by group, ordered by priority, with `ForgeMenuSeparatorEntry` between groups; `title` |
| `ForgeCommandListModel` | Every visible action by label, narrowed by a query (label or id, any case) |
| `ForgeKitStatusItem` | A status item: text, icon, tooltip, alignment, priority, tap, and `isActive(state)` |
| `ForgeContextMenuEntry`, `ForgeQuickPickItem` | The context-menu entries `contextMenus.entriesFor` resolves; the items of `dialogs.showQuickPick` (from `tom_forge_core`) |

## Routing to the active editor

`installForgeStandardEditingActions(api)` registers the standard editing
actions (cut, copy, paste, select all, undo, redo and the line actions) and
binds their default keys once, so one binding table routes them through
`executeAction` to the active editor; `forgeActionIdForKey(shortcuts, key)`
names the action of a pressed key (the platform's alternate keys included);
`forgeFindActionId` is Find. A widget showing an editor reports it to a state
that is a `ForgeEditorStateSink` (`DefaultKitState` is one). The panel shell
and `tom_forge_shared_ui`'s `ForgeEditorSurface` both route through these.

## Modules and their extras

`ForgeKitModule` is the module contract without layout. What an application
offers beyond it (the panel shell's settings sections, status items, external
tools) a module hands over as `ForgeModuleExtra`s, which the application
reads as it decides (`module.extras`). The kit defines one kind,
`ForgeKitStatusItemsExtra` (status items as `ForgeKitStatusItem` data); the
others are the application's.

A module that needs nothing of a host beyond this contract is a
`ForgeKitModule` and runs in any application on the kit: `DefaultKitApi`
registers it (`registerModule`), and so does the panel shell
(`DefaultShellApi.registerModule`), which reads its extras for its status bar
and places its editors. `ForgeKitModuleRegistry.allKitModules` answers every
registered module, whatever the host's own module type (`allModules` may
narrow to it).

License: BSD-3-Clause.

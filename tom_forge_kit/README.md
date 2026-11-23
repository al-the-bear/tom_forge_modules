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
| Look | `tom_forge_shared_ui` | Theme tokens and the shared widgets that draw the kit's data |
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

## Modules and their extras

`ForgeKitModule` is the module contract without layout. What an application
offers beyond it (the panel shell's settings sections, status items, external
tools) a module hands over as `ForgeModuleExtra`s, which the application
reads as it decides (`module.extras`).

License: BSD-3-Clause.

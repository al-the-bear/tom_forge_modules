# Context-menu contributions

How a module puts its actions into the shell's context menus, and how an
editor or view hands the shell what is under the pointer. Read this before
adding a right-click menu anywhere in `tom_forge_ui`, or a `contextMenus`
entry to a module.

## The model (`tom_forge_core`)

Three pure-Dart types in `src/types/forge_context_menu.dart`:

| Type | Role |
| --- | --- |
| `ForgeContextTarget` | What a menu is opened on: a **kind** (`forge.explorer.file`, `<module>.<unit>`), opaque **data** (a `Uri`, an editor's focus object), and the target's own **items**. |
| `ForgeContextMenuItem` | An item the target brings itself — a command only the producer can perform (a grid's *Clear cell*, a row's *Rename…*). |
| `ForgeContextMenuContribution` | A module's declaration: action **id** × target **kind**, with `isApplicable`, `label` and `unavailableReason` reading the target. |

Rules the shell applies when it draws a target:

- **Contributions first, in module and declaration order**, a divider where
  `group` changes; then the target's own items, skipping any whose id is a
  contributed action already drawn (the body's performance of an action is
  not a second entry).
- **Inapplicable is absent, unavailable is disabled.** `isApplicable == false`
  leaves the entry out; a non-null `unavailableReason` lists it disabled with
  the reason as its **tooltip**. When a contribution gives no
  `unavailableReason`, the action's own `isEnabled()` decides.
- **The action runs with the target**:
  `action.execute({ForgeContextTarget.parameterKey: target})`. An action that
  normally acts "at the focus" should act at the target when one is passed —
  a menu opened on another document's tree row acts on that row.
- The action is resolved from the shell's action registry by id, so the
  module registers it as any other action; the contribution only places it.

## Drawing (`tom_forge_ui`)

`shell.contextMenus` is a `ForgeContextMenuController`:

- `entriesFor(target)` — the resolved entries (`ForgeContextMenuEntry`), for a
  surface that draws its own menu and appends the contributions. The shell's
  `ForgeFileExplorerView` does this for its rows (`contextMenus:` parameter;
  kinds `ForgeContextTarget.explorerFileKind` / `explorerDirectoryKind`, data
  the row's `Uri`).
- `show(target, position)` — asks the scaffold to draw the menu. Returns
  false when nothing applies or no scaffold is mounted, so the caller can
  fall back to its own menu. The `ForgeShellScaffold` binds itself as the
  `presenter` in `initState` and unbinds in `dispose`.

Two ways an editor's units reach it:

1. **Implement `ForgeContextTargetProvider`** — `contextTargetAt(Offset)`.
   The scaffold asks the active editor on a secondary tap in the editor area;
   a non-null target with entries is drawn instead of the generic editor
   menu (Cut / Copy / Paste / Find / …), null falls through to it.
2. **Report it yourself** — a body that already handles its own right-click
   (a grid cell, a board card) builds the target and calls
   `shell.contextMenus.show(target, position)`. Answer null from
   `contextTargetAt` for those units, or the shell's menu and the body's
   would both open.

`forgeContextMenuItems(entries)` and `showForgeContextMenu(...)` in
`src/widgets/forge_context_menu.dart` are the one rendering; every entry has
the key `forge-context-menu:<id>` (`forgeContextMenuEntryKey`), which tests
find.

## Do not

- Do not add a `showMenu` with hard-coded items for something a module could
  contribute to — route it through the controller.
- Do not put a module's name or a specific editor's kinds into `tom_forge_*`.
  Kinds are strings the module owns; the shell knows only its own explorer
  kinds.
- Do not make `isEnabled()` of a module action depend on the pointer: the
  contribution's `unavailableReason` is where the target is read.

Tests: `tom_forge_core/test/context_menu_model_test.dart`,
`tom_forge_ui/test/widgets/module_context_menu_test.dart`.

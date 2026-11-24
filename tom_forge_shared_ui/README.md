# Tom Forge Shared UI

The look Forge's shell and the applications beside it share, without the
shell and without a layout: one rendering of the models of `tom_forge_kit`.
Each element takes its data from the kit and acts through its `ForgeKitApi`;
it works without the panel shell (over a bare `DefaultKitApi`). An
application uses an element, draws the kit's model its own way, or leaves the
element out.

## Tokens

- **`ForgeShellTheme`**: the shell's colour tokens as a `ThemeExtension`
  (panel surface and divider, active tab, drop zones, section header, status
  bar, chord popup, shortcut keys, focus ring) in three sets: `dark()`,
  `light()` and `highContrast()`. `ForgeShellTheme.forMode(mode,
  platformBrightness:, highContrast:)` picks one; `ThemeMode.system` follows
  the platform's brightness.
- **`forgeThemeData(brightness, highContrast:)`**: a Material `ThemeData`
  with the matching shell theme in its `extensions:`.
- **`ForgeDimensions`**: panel sizes, bar heights, divider hit target, icon
  sizes.
- **`ForgeAnimations`**: transition durations and curves, all zero and
  linear while `reduceMotion` is set.

## Elements over the kit's models

| Element | Kit model | Widget |
| --- | --- | --- |
| Action bar | `ForgeActionBarModel` (action ids in sections), each action a `ForgeActionState` from the action registry and shortcut table | `ForgeKitActionBar(api:, model:)`: icon buttons, divided groups, an overflow menu; follows the focus, the open editors, the active editor's state and the key bindings; runs `api.executeAction` |
| Status bar | `ForgeKitStatusItem`s, shown while `isActive(api.state)` | `ForgeKitStatusBar` (`.forApi(api:, items:)`): rebuilt on the kit state's changes, with the inline progress of `api.progress`; `moreItems` adds items an application draws its own way |
| Context menu | `ForgeContextMenuEntry`s of `api.contextMenus.entriesFor(target)` | `ForgeContextMenuPresenter` binds itself as the controller's `presenter` while in the tree, so `api.contextMenus.show(target, position)` draws there; `showForgeKitContextMenu` draws one directly; an entry with `children` is a submenu opened beside its row, a `checked` one shows a checkmark (`runForgeContextMenuEntry` for a surface drawing its own menu) |
| Quick pick, input box | `api.dialogs.showQuickPick` (`ForgeQuickPickItem`s), `api.dialogs.showInputBox` | `ForgeDialogPresenter` binds a `DefaultDialogManager` and hands each request to its `show` as a `ForgeQuickPickOverlay` / `ForgeInputBoxOverlay`; `ForgeDialogLayer` places them over a child |
| Notifications | `api.notifications` (the kit's `DefaultNotificationManager`) | `ForgeNotificationLayer` (`.forApi`): the toasts (`ForgeNotificationOverlay`) and, while `popupVisible`, the history (`ForgeNotificationPopup`); `forgeNotificationManagerOf(api)` |
| Focus indicator | `api.state.focusedComponent` | `ForgeFocusIndicator.kit(state:, component:)`: the ring while the component has the kit's focus |
| Menus | `ForgeMenuModel.of(api, location)`: the actions of a `ForgeMenuLocation` by group, with separators | `ForgeMenuButton(api:, location:)` (a menu anchor, no menu bar imposed); `forgeMenuChildren(api, model)` for an application's own `MenuBar` |
| Command list | `ForgeCommandListModel.of(api, query:)` | `ForgeCommandList(api:, onRun:)`: a filter field and the matching actions with their keys; arrows, Enter or a click run one through `api.executeAction` — a body a palette, a dialog or a side area hosts |
| Editor | any `ForgeEditor` | `ForgeEditorSurface(api:, editor:)`, below |
| File state | the kit's `ForgeSessionFile` (an editor's controller bound to its `ForgeFileSession`) | `ForgeSessionFileFrame(file:, child:)`: the editor with the file's state above it — loading, not readable, a refusal, read-only, deleted on disk, or changed on disk with *Keep mine* / *Take theirs* |

The earlier constructors stay: `ForgeActionBar(groups:)` over
`ForgeActionGroup`s of `ForgeActionItem`s, `ForgeStatusBar` over
`ForgeStatusItem`s (visibility listenable, colour, emphasis, a widget of its
own), `ForgeFocusIndicator` for keyboard focus, `ForgeNotificationOverlay` /
`ForgeNotificationPopup` over a manager, `showForgeContextMenuEntries`, and
the overlays answering through a `Completer`; `ForgeErrorRecoveryDialog`
(retry, cancel and optionally overwrite) and `ForgeFixedListenable`.

## `ForgeEditorSurface`

Shows a `ForgeEditor` (its `buildMain`) connected to the kit, the way the
panel shell connects the editors of its tabs, without a layout:

- **State.** The editor is reported open to `api.state` while the surface is
  in the tree, and active (the editor the kit's actions go to) when the focus
  enters it — for a state that is a `ForgeEditorStateSink`, as
  `DefaultKitState` is.
- **Undo, redo, clipboard.** The kit's standard editing actions and keys are
  installed when missing (`installForgeStandardEditingActions`); a key the
  editor leaves unhandled is looked up in the kit's binding table
  (`forgeActionIdForKey`) and run by `api.executeAction`, so undo, redo, cut,
  copy, paste and select all reach the editor by key, by `api.undo()` /
  `api.redo()` and by action id alike, through its `EditorActionProvider`.
  The editor uses the kit's clipboard (`api.clipboard`).
- **Find.** Unless another owner registered Find (`forgeFindActionId`), the
  active surface registers it (primary modifier + F when free): a find field
  above the editor searches a `ForgeFindTarget` through its own search, a
  `ForgeTextEditor` through `findAll`; Enter and Shift+Enter move between the
  matches, Escape closes it. `ForgeEditorSurfaceState.openFind` /
  `closeFind` drive it from outside.

## Dependencies

It depends on Flutter, `tom_ui_support`, `tom_forge_core` and
`tom_forge_kit` only (the platform architecture's layer 3, the guard's
PL-6): no shell, no terminal, no editors, no webview. The kit brings the
`shared_preferences` plugin. `tom_forge_shell` depends on it and re-exports
it, so code that imports `package:tom_forge_shell` or `package:tom_forge_ui`
sees the same names; Webwork takes it without the shell.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

MaterialApp(
  themeMode: ThemeMode.system,
  theme: forgeThemeData(Brightness.light),
  darkTheme: forgeThemeData(Brightness.dark),
  highContrastTheme: forgeThemeData(Brightness.light, highContrast: true),
  highContrastDarkTheme: forgeThemeData(Brightness.dark, highContrast: true),
  home: Builder(
    builder: (context) {
      final shell = Theme.of(context).extension<ForgeShellTheme>()!;
      return ColoredBox(color: shell.panelSurface);
    },
  ),
);

ForgeActionBar(
  groups: [
    ForgeActionGroup(
      id: 'edit',
      items: [
        ForgeActionItem(
          id: 'copy',
          icon: Icons.copy,
          label: 'Copy',
          shortcut: '⌘C',
          enabled: hasSelection, // a ValueListenable<bool>
          onInvoke: copy,
        ),
      ],
    ),
  ],
);

ForgeStatusBar(
  items: [
    ForgeStatusItem(text: lineAndColumn), // a ValueListenable<String>
    ForgeStatusItem(
      text: const ForgeFixedListenable('Syncing'),
      visible: syncing, // a ValueListenable<bool>
      alignment: StatusBarAlignment.right,
    ),
  ],
);

// Over the kit (`api` a ForgeKitApi, e.g. a DefaultKitApi): the elements
// read the kit's models and act through it.
ForgeDialogLayer(
  dialogs: api.dialogs,
  child: ForgeNotificationLayer.forApi(
    api: api,
    child: ForgeContextMenuPresenter(
      controller: api.contextMenus,
      child: Column(
        children: [
          Row(
            children: [
              ForgeMenuButton(api: api, location: ForgeMenuLocation.file),
              ForgeKitActionBar(
                api: api,
                model: ForgeActionBarModel.of(['file.save', 'forge.edit.undo']),
              ),
            ],
          ),
          Expanded(child: ForgeEditorSurface(api: api, editor: editor)),
          ForgeKitStatusBar.forApi(api: api, items: statusItems),
        ],
      ),
    ),
  ),
);
```

`example/` is a minimal app over the package: an action bar that changes a
counter, a status bar that shows it and a busy item while work runs, the
input box renaming the document, the quick pick setting the count, and a
toast whose action resets it, and a right-click menu on the panel. Building it for macOS, the web, iOS and
Android shows the package builds on each.

## License

BSD-3-Clause, see [LICENSE](LICENSE).

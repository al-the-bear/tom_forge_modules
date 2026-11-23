# Changelog

## 0.2.0 (unreleased)

- `ForgeSessionFileFrame`: the state of a file an editor reads and saves
  through the kit's `ForgeSessionFile`, drawn above the editor (re-exported
  from `tom_file_session_ui`, one implementation with `tom_file_editors`).
- The package draws the models of `tom_forge_kit` and depends on it; it
  imposes no layout, and every element works without the panel shell.
- Action bar: `ForgeKitActionBar(api:, model:)` over a
  `ForgeActionBarModel`, following the kit's state and key bindings, and
  `ForgeActionBar.kitGroups`; `ForgeActionBar(groups:)` is unchanged.
- Status bar: `ForgeKitStatusBar` over `ForgeKitStatusItem`s (and
  `.forApi`), filtered by the kit state and rebuilt on its changes, with the
  progress inline.
- Context menu: `showForgeKitContextMenu` and `ForgeContextMenuPresenter`
  over the kit's `ForgeContextMenuController`.
- Dialogs: `ForgeDialogPresenter` and `ForgeDialogLayer` draw the kit's
  quick pick and input box (`api.dialogs`).
- Notifications: `ForgeNotificationLayer` (toasts and history together),
  `ForgeNotificationOverlay.forApi`, `ForgeNotificationPopup.forApi`,
  `forgeNotificationManagerOf`.
- Focus: `ForgeFocusIndicator.kit` follows the kit's focused component.
- New: menus (`ForgeMenuButton`, `forgeMenuChildren`, `forgeMenuEntryKey`
  over a `ForgeMenuModel`), the command list (`ForgeCommandList`,
  `forgeCommandListEntryKey`), and `ForgeEditorSurface`, which shows any
  `ForgeEditor` connected to the kit: its state, its keys, undo, redo, the
  clipboard and find.
- `ForgeContextMenuEntry`, `ForgeQuickPickItem` and `StatusBarAlignment` live
  in `tom_forge_core` now and are re-exported from where they were, so this
  package's users are unchanged.

## 0.1.0

- `ForgeActionBar` over `ForgeActionGroup` / `ForgeActionItem`: groups,
  enablement per item, overflow menu. Forge's title-bar action bar uses it.
- `ForgeStatusBar` over `ForgeStatusItem` (visibility listenable, colour,
  emphasis, widget slot), with a rebuild listenable and a progress message.
  `StatusBarAlignment` moved here. Forge's status bar renders through it.
- `ForgeFixedListenable`.
- `ForgeInputBoxOverlay`, `ForgeQuickPickOverlay` with `ForgeQuickPickItem`,
  `ForgeErrorRecoveryDialog` with `ErrorRecoveryAction`, and
  `ForgeFocusIndicator`, taken out of `tom_forge_shell`, which re-exports
  them.
- `ForgeNotificationOverlay` and `ForgeNotificationPopup`, taken out of
  `tom_forge_shell`; the package now depends on `tom_forge_core` and
  re-exports its `DefaultNotificationManager`, `NotificationItem` and
  `NotificationSeverity`. Choosing a toast's action now also removes the
  toast (it used to stay on screen after answering).
- Context menus: `ForgeContextMenuEntry`, `forgeContextMenuItems` and
  `forgeContextMenuEntryKey`, taken out of `tom_forge_shell`, and the new
  `showForgeContextMenuEntries`. The shell keeps `ForgeContextMenuController`
  and `showForgeContextMenu`, which draws through it.

- `ForgeShellTheme` (dark, light, high contrast), `ForgeDimensions` and
  `ForgeAnimations`, taken out of `tom_forge_shell`, which re-exports them.
- `ForgeShellTheme.forMode` follows the platform's brightness for
  `ThemeMode.system`; high contrast is its own flag.
- `forgeThemeData`: the Material theme of a Forge application with the shell
  theme installed.

# Changelog

## 0.1.0

- The layout-free part of `tom_forge_shell`, taken out of it with its history:
  the components and editor contracts, the actions, shortcut bindings and
  shortcut menus, the action registry and shortcut manager, the module
  storage, dialogs, navigation history (interface), outline, workspace state,
  file decorations, accessibility, the context-menu controller and the host
  ports, the editor integration (`ShellEditorIntegration`, typed on
  `ForgeKitApi`) and the default services.
- `ForgeKitState`, `ForgeKitApi`, `ForgeEditorHost`, `ForgeStateStore`
  (interface), `ForgeKitModule` with `ForgeModuleExtra`s,
  `ForgeKitModuleRegistry` and `DefaultKitModuleRegistry`, `DefaultKitApi`
  and `DefaultKitState`, `ForgeKitStatusItem`, `ForgeKitEditorChoice`,
  `ForgeAutosaveController`, `ForgeKitPreferences`.
- The state-store port: `ForgeStateStore` with `ForgeMemoryStateStore`,
  `ForgeSharedPreferencesStateStore` and `ForgeFileStateStore`, and
  `ForgeCoalescedStateWriter`. `ForgeKitPreferences` and
  `DefaultWorkspaceStateManager` read and write only through a store, once
  per gesture and never before the start's restore; `DefaultKitApi.restore`
  and `flushed`.
- `example/`: a minimal application over `DefaultKitApi`, built for the web,
  iOS, Android and macOS.
- `ForgeContextMenuEntry`, `ForgeQuickPickItem` and `StatusBarAlignment` are
  re-exported from `tom_forge_core`, where they moved from
  `tom_forge_shared_ui` (plain data both draw on; `tom_forge_shared_ui`
  re-exports them too).

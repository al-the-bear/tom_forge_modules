# Changelog

## Unreleased

- Editor types without layout: `ForgeKitEditorType` (an id, a name, the file
  extensions it opens by default and a factory) and `ForgeKitEditorRequest`
  (the file, its content, the module, the application's API, its file system
  and an opaque host value). An editor adapter exports its type; the panel
  shell takes them through its components. `ForgeKitApiProvider` and
  `forgeKitApiOf`: the API a module was activated with, which an editor made
  for it reaches the application through.
- A layout-free placement hint: `ForgeEditorHost.showEditor` and
  `openEditorFor` and `ForgeKitApi.openFile` take `placement:`, an opaque
  value the application interprets (e.g. `ForgeNavigationLocation.placement`);
  `DefaultKitApi.openFile` passes it to the editor host. Implementers of
  `ForgeEditorHost` add the parameter.
- `ForgeKitModuleRegistry.allKitModules`: every registered module, whatever
  the host's module type; the context-menu controller and
  `DefaultKitApi.openFile` iterate it.
- `ForgeKitStatusItemsExtra`: a module's status items as data, the one
  `ForgeModuleExtra` kind the kit defines.
- The models the elements of `tom_forge_shared_ui` draw: `ForgeActionState`
  (with `forgeActionEnabled`), `ForgeActionBarModel` with
  `ForgeActionBarSection`, `ForgeMenuModel` with `ForgeMenuActionEntry` and
  `ForgeMenuSeparatorEntry` (and `forgeMenuTitle`), `ForgeCommandListModel`.
  `ForgeKitStatusItem` gains an `icon`.
- The routing to the active editor, shared by the panel shell and any editor
  surface: `installForgeStandardEditingActions`, `forgeActionIdForKey`,
  `forgeFindActionId` and `ForgeEditorStateSink`, which `DefaultKitState`
  implements.

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

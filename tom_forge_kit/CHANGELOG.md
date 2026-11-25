# Changelog

## Unreleased

- **Configuration contributions and values:** a module hands its
  components' configuration descriptions (`tom_forge_core`) over as a
  `ForgeConfigurationDescriptionsExtra` (`forge.kit.configurationDescriptions`);
  `forgeConfigurationDescriptions(registry)` / `forgeConfigurationDescriptionsOf(api)`
  collect them from every registered module (the first description of an id
  wins). `ForgeConfigurationValues` keeps their values through the
  state-store port: `valueOf` (the stored value when valid, else the default;
  a refused stored value is reported in `problems` / `onProblem`), `set`
  (validates; refused values are not written), `reset`, `isStored`,
  `isVisible` / `isEnabled`, `listenable`, `changes`, `load` / `reload` /
  `flushed`; settings with a storage path share their key's document, and
  the writes of one gesture are one store write. `tom_configuration_ui`
  draws the tiles.
- **Bindings, companions and hooks in `ForgeConfigurationValues`:** a
  setting whose storage names a binding is read from, written to (coalesced
  per gesture, nothing before `load`) and followed through that
  `ForgeSettingBinding` (`bindings:`, `addBinding`; a missing binding keeps
  the default and `set` refuses, `storageProblem`); state-store settings
  behave as before. A setting's companions are kept and `reset` clears them
  too; settings that keep no value are not stored. The hooks a setting
  names run through the service's `hooks` registry: `contextFor`,
  `runAction` (a returned value is written; a missing or throwing hook is a
  failure), `startFlow` (the done step's value is written), `checkToolPath`
  / `detectToolPath` (the application's hints merged), `choicesFor`,
  `statusOf` / `watchStatus`, `catalogueOf`, `keyBindingRows`. Modules hand
  hooks over as a `ForgeConfigurationHooksExtra`
  (`forge.kit.configurationHooks`), merged by `forgeConfigurationHooks` /
  `forgeConfigurationHooksOf`. Trail: `kConfigurationValuesDebug` (`[CV …]`)
  for reads, writes, binding changes and hook runs.

- `ForgeExternalTool.buildHelp(context, copy, checkAgain:)`: help a tool
  shows in its row while its copy is not usable (default none); the panel
  shell's *External Tools* section shows it under the row instead of the
  download line.
- **External tools** in the kit: `ForgeExternalTool`, `ForgeToolCopy`,
  `ForgeToolState` (from `tom_forge_shell`, which re-exports them with the
  kit) and the extra `ForgeExternalToolsExtra` (`forge.kit.externalTools`),
  so a kit module contributes the rows of the panel shell's *External Tools*
  section without the shell.
- **Open With ▸** as data: `forgeOpenWithMenuEntry(picker, choices)` builds
  the context-menu entry for an item with more than one editor (null
  otherwise) — the editors, each opening the item once (`openOnce`, or the
  application's `open:`), the default checked and labelled `(default for
  .md)`, and an inner **Set default for .md ▸** (or the content type) whose
  checked entry is the default and whose others make themselves the default
  without opening anything. Ids `forgeOpenWithMenuId`,
  `forgeOpenWithSetDefaultMenuId`, `forgeOpenWithChoiceMenuId`,
  `forgeOpenWithDefaultMenuId`; `forgeOpenWithDefaultScope`.
- Choosing the editor: `ForgeEditorPicker` (`ForgeKitApi.editorPicker`) —
  for a `ForgeContentItem` (a URI with an optional content type) the editors
  of every module and editor type, by extension and by content type, with the
  default marked (`ForgeEditorChoices`); `openOnce`, `open`, `setDefault` /
  `setDefaultId` / `clearDefault` per content type or per extension
  (`ForgeEditorDefaultScope`), kept in a `ForgeEditorDefaults`, and an
  application-supplied `fallback` choice for content nobody takes.
  `ForgeKitEditorChoice.contentTypes` and `ForgeKitEditorType.contentTypes`
  (and `icon`) declare the content types an editor opens;
  `ForgeKitModule.contentTypeEditorChoices` and `editorChoicesForContent`
  let a module offer editors by content type. `ForgeKitPreferences`
  implements `ForgeEditorDefaults`: content-type defaults under the new key
  `forge.files.contentTypeDefaults`, extension defaults under
  `forge.files.typeDefaults` as before. `DefaultKitApi` takes `editorTypes`
  and `fallbackEditor` and opens a type with `openWithEditorType`. Helpers
  `forgeNormalizeContentType`, `forgeContentTypeAccepted`,
  `forgeExtensionOf`.
- Quick open as a contribution: `ForgeQuickOpenExtra` (a builder taking a
  `ForgeQuickOpenRequest` — the API, the `ForgeQuickOpenMode` (all,
  actions, chord), the search field the application hosts, the chord
  pending, what to do on open file, help and settings — with the modes it
  shows and a priority), found with `forgeQuickOpenBuilderFor`;
  `ForgeKitModulesHost` (`DefaultKitApi` is one) and `forgeKitModulesOf`,
  the registered modules of an API; `ForgeTerminalSectionsExtra` and
  `forgeTerminalSectionsHint`, where an application shows its terminals.
- View ports for the file explorer, Search and Problems views:
  `ForgeFileNavigator` (open a file at a line and column; implemented by
  the panel shell's API) with `ForgeOpenFileAt` and `forgeOpenFileAtOf`
  (falls back to `ForgeKitApi.openFile`); `ForgeExplorerSelection`,
  `ForgeSearchQueryState` and `ForgeWorkspaceRoot` (implemented by the
  panel shell's state).
- Contributed views: `ForgeViewPlacementHint` (a stable id, a
  `ForgeViewRole` — navigation, details, messages —, a group with its icon,
  an order; no panel, tab or window), handed over per view in a
  `ForgeViewContributionsExtra`; `forgeContributedViews` answers the
  registered modules' views with their hints, `forgeContributedViewById`
  finds one. `ForgeActiveEditorListenable` (implemented by `DefaultKitState`)
  and `ForgeRevisionRestorer`, the two ports the Revisions view needs.
- `ForgeKitEditorType.actionDescriptors`: the editor's own actions as its
  package declares them, so an application lists them (the panel shell: in
  its shortcut editor) before an editor of the type is open, without naming
  the editor. Empty by default.
- File kinds: `ForgeKitFileKind` (an id, a label and icon for Open With, the
  extensions and a factory taking a `ForgeFileKindRequest`: the session, the
  module, the application's API) and `ForgeFileKindRegistry`, which the
  application fills and hands its file module. `ForgeSessionFile` binds an
  editor's controller to its `ForgeFileSession` (re-exported from
  `tom_file_session_ui`, the implementation `tom_file_editors` uses too); the kit re-exports
  `ForgeFileSession`, `ForgeFileSessionState`, `ForgeFileSaveOutcome` and
  `forgeReadOnlyAbove` from `tom_file_session` (a new dependency).
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

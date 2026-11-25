# Tom Forge Shell

Forge's panel shell core, an application of the layout-free kit
`tom_forge_kit`: the component, editor and module contracts, actions and
shortcuts, the routing to the active editor, autosave, the default services,
`ForgeKitApi`, the `ForgeEditorHost` port and the `ForgeStateStore` port are
the kit's. The shell adds the panel layout: `ForgeShellApi` (`ForgeKitApi` plus
the layout, applications, navigation history, status bar, modules and
terminals), `ForgeModule` (the kit's module contract plus the status bar
items, settings sections and external tools the shell reads, also offered as
module extras), `ForgeTabEditorHost` (`ForgeEditorHost` with tabs) and the
panel shell's preferences (`ForgePreferencesService`, through a
`ForgeStateStore`, by default shared_preferences with the keys as before). It
re-exports the kit for one release so its consumers keep compiling; a
component or adapter takes the kit, not the shell.

## Modules written against the kit

The shell's registry takes a module written against the kit alone
(`ForgeKitModule`) beside its `ForgeModule`s: `DefaultShellApi.registerModule`
activates it with the shell's API (a `ForgeKitApi`) and registers its actions,
shortcuts and shortcut menus (`DefaultModuleRegistry.register` takes it too,
after `activate`). `modules.allModules` keeps answering the `ForgeModule`s;
`modules.allKitModules` answers every module, and `modules.get<T>()` finds
either. The shell takes a kit module's editors, views, actions, context-menu
contributions, `openUri` and Open With choices (opened in the middle panel
asked for by making it the active one first) wherever it takes a
`ForgeModule`'s, and reads its extras:

| Extra | Defined in | A kit-only module can offer it |
| --- | --- | --- |
| `ForgeKitStatusItemsExtra` (status items as data, `ForgeKitStatusItem`) | kit | yes; shown in the status bar while `isActive` holds |
| `ForgeViewContributionsExtra` (its views' layout-free placement hints, `ForgeViewPlacementHint`) | kit | yes; the panels are laid out from them (below) |
| `ForgeExternalToolsExtra` (`ForgeExternalTool` descriptors, rows of the Configuration panel's *External Tools* section) | kit | yes; a row each, its path setting `forge.tools.<id>.path` in the preferences |
| `ForgeSettingsSectionExtra` (a `ForgeConfigPanel` of the configuration dialog) | shell | no: a section of the shell's dialog |
| `ForgeStatusItemsExtra` (`StatusBarItem`s over the shell's state) | shell | no: the shell's status bar items |

`forgeModuleStatusItems`, `forgeModuleSettingsSections` and
`forgeModuleExternalTools` read them (a `ForgeModule`'s from its members).

## The configuration side panel

The side panel draws one `tom_configuration_ui` tile per section of the
configuration descriptions the modules contribute
(`ForgeConfigurationDescriptionsExtra`, `ForgeConfigurationHooksExtra`),
followed by the built-in sections (the editors, shortcuts, file types,
external tools) and the module panels.

The shell's own options are such a description, `ForgeShellConfiguration`:
the *Shell* section (theme, high contrast, recent workspaces, auto save,
search, layout dimensions, reduce motion) and the *Terminal* section
(default shell, shell paths, start folder, font, size, scrollback). The
scaffold registers `ForgeShellConfigurationModule`, which contributes it,
and gives its values service two storage bindings
(`forgeShellSettingBindings`):

- `ForgePreferencesSettingBinding` (`forge.preferences`) reads and writes
  through `ForgePreferencesService`, under its `forge.*` keys and in its
  encodings (the search configuration stays one JSON text, its file-size
  limit in bytes, shown in MB). The service notifies as before, so the
  theme, high contrast, reduce motion, the search configuration and the
  layout dimensions are applied as they always were.
- `ForgeConfigSettingBinding` (`forge.config`) keeps the auto-save in the
  shell's `DefaultConfigManager` (`ForgeConfig.autoSave`).

Quick open names a section by its index (`ForgeConfigurationPanel`: 0
*Shell*, 1 *Terminal*, 2 *Dart Editor* ... 8 *External Tools*, then the
module panels); the panel maps 0 and 1 to the described sections.

## Placing contributed views

The shell names no view. `forgeContributedPanelTabs(modules, location)` makes
the tabs of a side or bottom panel from the views the registered modules
contribute with a placement hint: a hint's role maps to a panel
(`forgePanelLocationOf`: navigation left, details right, messages bottom),
each hint group is a tab titled by the group with the group's icon, and tabs
and sections follow the hints' order. `forgeContributedPanelLayout(modules)`
is a whole panel layout from them; with no view contributed its panels are
empty and the shell still starts. An application lays its panels out from
these tabs and adds its own beside them (Tom Forge adds the website editor's
tabs and the terminal tab).

## Quick open, the command palette and the terminal tab

The shell names neither quick open nor the command palette: when the user
opens one (F1, ⌘⇧P, ⌘P, a chord, typing in the title bar's search field),
the scaffold asks the registry for the overlay a module contributes
(`forgeQuickOpenBuilderFor`, a kit `ForgeQuickOpenExtra`) and shows it below
the search field with a `ForgeQuickOpenRequest` (the field's controller and
focus node, the chord pending, opening a file, the help and the settings).
Without a contribution nothing opens. `tom_forge_quick_open`
(`forgeQuickOpenModule()`) and `tom_forge_command_palette`
(`forgeCommandPaletteModule()`, a lower priority) contribute one each.

The tab that holds the terminals is a `PanelTabConfig` with
`terminalSections`: the scaffold keeps one section per open terminal in it
and offers New Terminal on it. `forgeContributedTerminalTab(modules)` makes it
from the placement a terminal module contributes (a kit
`ForgeTerminalSectionsExtra`; `tom_forge_terminal`'s `forgeTerminalModule()`),
null when none does.

## Placing editors

`ForgeTabEditorHost` reads the kit's placement hint
(`ForgeEditorHost.showEditor` / `openEditorFor` `placement:`,
`ForgeKitApi.openFile` `placement:`) as the index of a middle panel, the value
the shell records in `ForgeNavigationLocation.placement`; a hint that names no
existing middle panel places the editor in the active one
(`ForgeTabEditorHost.middlePanelIndexOf`).

It holds its default services
(`DefaultShellApi`), the scaffold (`ForgeShellScaffold`), panels, editor tab
bar, menus, configuration (the views, quick open and the command palette
are packages of their own — `tom_forge_file_explorer`,
`tom_forge_search_view`, `tom_forge_problems_view`, `tom_forge_outline_view`,
`tom_forge_output_view`, `tom_forge_revision_view`, `tom_forge_quick_open`,
`tom_forge_command_palette` — which it does not depend on; its API and state
are the kit's view ports `ForgeFileNavigator`, `ForgeExplorerSelection`,
`ForgeSearchQueryState`, `ForgeWorkspaceRoot`, `ForgeActiveEditorListenable`
and `ForgeRevisionRestorer`), and opens a file no
editor type takes in the plain-text editor, `ForgePlainTextEditor` of the
adapter `tom_forge_plain_text_editor` (which it depends on and does not
re-export). Its look — `ForgeShellTheme`, `forgeThemeData`, `ForgeDimensions`,
`ForgeAnimations` and the elements that draw the kit's models — is
`tom_forge_shared_ui`, which it re-exports, so the applications beside the
shell share it without depending on the shell. The scaffold draws its title
action bar with `ForgeKitActionBar` over a `ForgeActionBarModel`, its status
bar with `ForgeKitStatusBar`, the kit's quick pick and input box with
`ForgeDialogPresenter`, the notifications with `ForgeNotificationLayer` and
the context menu with `showForgeKitContextMenu`; its key routing takes the
kit's (`installForgeStandardEditingActions`, `forgeActionIdForKey`).

**Choosing the editor.** `DefaultShellApi.editorPicker` is a
`ForgeShellEditorPicker`: the modules' choices, the editor types, the shell's
own plain-text editor (`Plain text`, for any file of no known binary content
type, `forgePlainTextOpens`) and the editors open on the file. The editor
tab's context menu has **Open With ▸** for a file with more than one editor
(`forgeOpenWithMenuEntry`: an editor opens it once in that tab's panel; **Set
default for .ext ▸** moves the default), as the file explorer's row menu has;
the configuration's **File Types** section lists every default, follows one
moved from the menu and resets it; each extension's choice offers every editor
the picker knows for it (a module's included).

It carries no terminal, no code editor, no keychain, no native file dialog
and no `dart:io`, so it builds where those do not, the web included. They plug
in through `ForgeShellComponents`:

- a terminal-manager factory and the view of a terminal (`tom_forge_terminal`);
- editor types the layout controller opens files with: any of the kit's
  `ForgeKitEditorType`s, such as the editor adapters' `forgeMarkdownEditorType`
  (`tom_forge_md_editor`), `forgeDartEditorType` (`tom_forge_dart_editor`) and
  `forgeYamlEditorType` (`tom_forge_yaml_editor`), or a `ForgeEditorType`
  whose factory takes the shell's `ForgeEditorTypeRequest`;
- a secret-storage factory (`tom_forge_platform_secrets`);
- the file pickers (`ForgeFilePickers`: folder, files, save location) and the
  host environment (`ForgeHostEnvironment`: installed shells, folders outside
  the workspace) (`tom_forge_desktop_host`).

A shell takes the components it is given (`DefaultShellApi.withDefaults…(
components: …)`) or the registered ones (`ForgeShellComponents.register`).
Without any it has no terminals (`ForgeNoTerminalManager`), keeps secrets in
memory, opens files as plain text and picks nothing (`ForgeNoFilePickers`,
`ForgeNoHostEnvironment`). `tom_forge_ui` is this package with all four
parts, and `useForgeDesktopComponents()` registers them.

An editor tells the shell its type by implementing `ForgeEditorOfType`
(`editorTypeId`): the text settings, the action bar and **Open With** are keyed
by it. An editor that takes the shell's text options implements
`ForgeTextOptionsReceiver`.

Part of Tom Forge; the layers are in `tom_ai/forge_modules/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

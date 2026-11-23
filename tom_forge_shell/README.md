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

It holds its default services
(`DefaultShellApi`), the scaffold (`ForgeShellScaffold`), panels, editor tab
bar, menus, command palette, quick open, configuration, the built-in views
(explorer, outline, output, problems, revisions, search) and the plain-text
editor. Its look — `ForgeShellTheme`, `forgeThemeData`, `ForgeDimensions`,
`ForgeAnimations` and the elements that draw the kit's models — is
`tom_forge_shared_ui`, which it re-exports, so the applications beside the
shell share it without depending on the shell. The scaffold draws its title
action bar with `ForgeKitActionBar` over a `ForgeActionBarModel`, its status
bar with `ForgeKitStatusBar`, the kit's quick pick and input box with
`ForgeDialogPresenter`, the notifications with `ForgeNotificationLayer` and
the context menu with `showForgeKitContextMenu`; its key routing takes the
kit's (`installForgeStandardEditingActions`, `forgeActionIdForKey`).

It carries no terminal, no code editor, no keychain, no native file dialog
and no `dart:io`, so it builds where those do not, the web included. They plug
in through `ForgeShellComponents`:

- a terminal-manager factory and the view of a terminal (`tom_forge_terminal`);
- editor types the layout controller opens files with (`tom_forge_code_editors`:
  Markdown, Dart, YAML);
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

Part of Tom Forge; the layers are in `tom_forge/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

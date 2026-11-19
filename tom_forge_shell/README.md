# Tom Forge Shell

Forge's panel shell core: `ForgeShellApi` and its default services
(`DefaultShellApi`), the scaffold (`ForgeShellScaffold`), panels, editor tab
bar, menus, command palette, quick open, configuration, the built-in views
(explorer, outline, output, problems, revisions, search) and the plain-text
editor. Its look — `ForgeShellTheme`, `forgeThemeData`, `ForgeDimensions`,
`ForgeAnimations`, the action bar and the status bar widgets, the input
box, quick pick, error recovery dialog and focus indicator, the notification
toasts and history, the context menu rendering — is
`tom_forge_shared_ui`, which it re-exports, so the
applications beside the shell share it without depending on the shell.

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

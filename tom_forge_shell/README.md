# Tom Forge Shell

Forge's panel shell core: `ForgeShellApi` and its default services
(`DefaultShellApi`), the scaffold (`ForgeShellScaffold`), panels, editor tab
bar, menus, command palette, quick open, configuration, the built-in views
(explorer, outline, output, problems, revisions, search) and the plain-text
editor.

It carries no terminal, no code editor and no keychain, so it builds where
those do not. They plug in through `ForgeShellComponents`:

- a terminal-manager factory and the view of a terminal (`tom_forge_terminal`);
- editor types the layout controller opens files with (`tom_forge_code_editors`:
  Markdown, Dart, YAML);
- a secret-storage factory (`tom_forge_platform_secrets`).

A shell takes the components it is given (`DefaultShellApi.withDefaults…(
components: …)`) or the registered ones (`ForgeShellComponents.register`).
Without any it has no terminals (`ForgeNoTerminalManager`), keeps secrets in
memory and opens files as plain text. `tom_forge_ui` is this package with all
three parts, and `useForgeDesktopComponents()` registers them.

An editor tells the shell its type by implementing `ForgeEditorOfType`
(`editorTypeId`): the text settings, the action bar and **Open With** are keyed
by it. An editor that takes the shell's text options implements
`ForgeTextOptionsReceiver`.

Part of Tom Forge; the layers are in `tom_forge/_copilot_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

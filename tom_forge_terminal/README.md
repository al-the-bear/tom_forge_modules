# Tom Forge Terminal

Forge's terminal for the panel shell (`tom_forge_shell`): PTY-backed
terminals (`PtyTerminalManager`) for a shell over a folder on disk,
process-backed ones (`DefaultTerminalManager`) otherwise, and the view a
terminal is shown in (`SingleTerminalView`, a kit `ForgeView`).

It is the Forge adapter of `tom_terminal_view`, which holds the shell in a
pseudo-terminal (`TomTerminalSession`, over `flutter_pty`) and the xterm
widget (`TomTerminalView`, the `xterm` fork) without Forge: a `PtyTerminal` is
Forge's `ForgeTerminal` over a session (`PtyTerminal.session`), and
`SingleTerminalView` shows it in a `TomTerminalView`. An application that
wants a terminal without Forge takes `tom_terminal_view` alone.

It takes the kit for the view (`ForgeView`, `ForgeAction`), `tom_forge_core`
for the terminal contracts and the shell only for `ForgeShellComponents`.

`forgeTerminalComponents` is all of it as `ForgeShellComponents`, which a shell
takes when it is made or which `ForgeShellComponents.register` registers
(`tom_forge_ui`'s `useForgeDesktopComponents()` does).

Part of Tom Forge; the layers are in `tom_forge/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

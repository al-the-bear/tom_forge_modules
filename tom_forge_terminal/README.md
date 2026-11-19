# Tom Forge Terminal

Forge's terminal for the panel shell (`tom_forge_shell`): PTY-backed
terminals (`PtyTerminalManager`, over `flutter_pty` and the `xterm` fork) for a
shell over a folder on disk, process-backed ones (`DefaultTerminalManager`)
otherwise, and the view a terminal is shown in (`SingleTerminalView`).

`forgeTerminalComponents` is all of it as `ForgeShellComponents`, which a shell
takes when it is made or which `ForgeShellComponents.register` registers
(`tom_forge_ui`'s `useForgeDesktopComponents()` does).

Part of Tom Forge; the layers are in `tom_forge/_copilot_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

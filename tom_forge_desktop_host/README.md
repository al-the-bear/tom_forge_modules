# Tom Forge Desktop Host

Forge's desktop host for the panel shell (`tom_forge_shell`):

- `DesktopFilePickers` — the native dialogs that choose a folder, files to open
  and the save location (`file_picker`, `file_selector`);
- `DesktopHostEnvironment` — the machine's installed shells and folders outside
  the workspace (`dart:io`);
- `forgeDesktopHostComponents` — both as `ForgeShellComponents`, which
  `tom_forge_ui`'s `forgeDesktopComponents` includes;
- `detectForgeWorkspaceRoot` / `keepForgeStateOutOfGit` — the workspace folder
  above a picked folder, and keeping `.forge/` out of git;
- `WorkspaceFolderSelector` — the dialog that picks a workspace folder from the
  recent ones or the native picker.

Without this part the shell core builds for the web: it picks nothing (Open
Folder, Open File and Save As do nothing), knows no installed shells and makes
no folders outside its workspace.

Part of Tom Forge; the layers are in `tom_ai/forge_modules/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

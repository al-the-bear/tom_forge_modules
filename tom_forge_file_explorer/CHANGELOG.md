# Changelog

## Unreleased

- **Open With ▸** in a file row's context menu, after Open, for a file with
  more than one editor: built from the application's editor picker
  (`ForgeFileExplorerView.editorPicker`, `ForgeKitApi.editorPicker` for
  `forApi`) with the kit's `forgeOpenWithMenuEntry` — the editors to open
  the file in once and **Set default for .ext ▸**.

## 0.1.0

- `ForgeFileExplorerView`, moved out of `tom_forge_shell` onto the kit (it
  opens files through `ForgeOpenFileAt` and shares its selection through a
  `ForgeExplorerSelection` instead of the shell's layout controller and
  state), and `forgeFileExplorerModule()`, the module that contributes it
  with its placement hint.

# Changelog

## 0.1.0

- `ForgeFileExplorerView`, moved out of `tom_forge_shell` onto the kit (it
  opens files through `ForgeOpenFileAt` and shares its selection through a
  `ForgeExplorerSelection` instead of the shell's layout controller and
  state), and `forgeFileExplorerModule()`, the module that contributes it
  with its placement hint.

# Changelog

## 0.1.0

- `ForgeSearchView`, moved out of `tom_forge_shell` onto the kit (it opens a
  match through `ForgeOpenFileAt` and records its query in a
  `ForgeSearchQueryState` instead of the shell's layout controller and
  state), and `forgeSearchViewModule()`, the module that contributes it with
  its placement hint.

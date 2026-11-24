# Changelog

## 0.1.0

- `ForgeProblemsView`, moved out of `tom_forge_shell` onto the kit (it opens
  a diagnostic through `ForgeOpenFileAt` instead of the shell's layout
  controller), and `forgeProblemsViewModule()`, the module that contributes
  it with its placement hint.

# Changelog

## 0.1.0

- `ForgeQuickOpen`, moved out of `tom_forge_shell` onto the kit (it takes a
  `ForgeKitApi`: the actions of its registry and of its modules through
  `ForgeKitModulesHost`, the open editors of its state, the workspace folder
  of the state's `ForgeWorkspaceRoot`; the mode is the kit's
  `ForgeQuickOpenMode`), `ForgeQuickOpen.fromRequest`, and
  `forgeQuickOpenModule()`, the module that contributes it as a
  `ForgeQuickOpenExtra` for every mode.

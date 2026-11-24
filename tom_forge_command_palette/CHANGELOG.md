# Changelog

## 0.1.0

- `ForgeCommandPalette`, moved out of `tom_forge_shell` onto the kit (it
  takes a `ForgeKitApi` — `api:` instead of `shellApi:` — and the actions of
  its modules through `ForgeKitModulesHost`; Toggle Left / Right Panel call
  `onTogglePanel`, else run `forge.toggleLeftPanel` /
  `forge.toggleRightPanel`), `ForgeCommandPalette.fromRequest`, and
  `forgeCommandPaletteModule()`, the module that contributes it as a
  `ForgeQuickOpenExtra` for the all and actions modes.

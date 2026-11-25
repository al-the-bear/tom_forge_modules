# Changelog

## 0.1.0

- `ForgeConfigurationTile`: one section of a configuration description
  (`tom_forge_core`) as a tile — its title with icon and help, then each
  visible setting with its label, its editor, a reset-to-default button, its
  help on request and the reason a value was refused (a typed one, or a
  stored one the setting refuses). Values are read from and written through
  the kit's `ForgeConfigurationValues` (the state-store port).
- `ForgeConfigurationTileStyle`: the look every tile shares — padding,
  spacing, header spacing, density, corner radius, border, header and icons,
  the `tom_flutter_ui` field family and form style; `compact` preset.
  Colours from the theme (`ForgeShellTheme` when installed).
- `forgeConfigurationTiles(values)`: the tiles of every section in section
  order, for the application to arrange; `ForgeConfigurationScope` shares
  the values, editors, style, path picker and icon resolver with the tiles
  below it.
- `ForgeSettingEditorRegistry`: the editors by setting kind;
  `ForgeSettingEditorRegistry.standard()` holds one for every kind
  `tom_forge_core` defines, built on `tom_flutter_ui`'s form fields
  (`TomFormFieldFamily`, through `ForgeSettingTomField`) where one fits; a new
  kind registers its editor.
- `ForgeConfigurationLabels`: every `ForgeText` resolved through Tom Core's
  text resources, the English fallback where nothing translates it or no
  bundle is installed; tiles follow `appResourcesRevision`.
  `ForgeConfigurationUiTexts`: the package's own strings.
- `forgeMaterialIconFor` / `ForgeConfigurationIconResolver`: section icons
  as constant `IconData`s, so builds keep shrinking the icon fonts.
- The `[CU` trail (`kConfigurationUiDebug`, switchable at run time).

# Changelog

## Unreleased

- `ForgeHelpPanelBuilder` takes a fourth argument, `recheck`: the help panel
  of a tool path asks its editor to check the value again (after an install,
  or on the panel's own *Check again*).
- Tiles fit narrow panels: below `ForgeConfigurationTileStyle.stackedBelowWidth`
  (280 px) an inline editor and the setting's buttons go on a line under the
  label; the colour field narrows with its row.

## 0.2.0

- **Editors for the new setting kinds** of `tom_forge_core`, so a component
  is described entirely by data; each runs the setting's hooks through the
  kit's `ForgeConfigurationValues`:
  - `fontFamily`: the name with a searchable font picker
    (`ForgeFontFamilyEditor`, `showForgeFontPicker`) over `choicesFor` — the
    suggestions, the provider's fonts drawn in their own font, the generic
    families, *Default font*, a *Fixed-width fonts only* filter for a code
    font, a typed name when custom names are allowed.
  - `keyBinding` / `keyChord`: `ForgeKeyCaptureField` — click, press a
    combination (a chord: strokes one after the other, *Done*), *Escape*
    cancels, *Clear* unbinds; labels per platform (`forgeKeyStrokeLabel`,
    `forgeKeyChordLabel`: `Ctrl+Shift+K`, `⇧⌘K`).
  - `keyBindingTable`: `ForgeKeyBindingTableEditor` — the catalogue's actions
    (`catalogueOf`, followed through its `changes`) with their bindings in
    effect, grouped, a search box, conflicts marked
    (`forgeKeyBindingConflicts`), per-row capture, reset, removal (the
    deleted bindings companion) and *Bind for every editor* (wildcard rows
    shown as *All editors*), *Reset all*.
  - `toolPath`: `ForgeToolPathEditor` — the path, *Browse…*, *Check again*,
    the detector's state line (`checkToolPath`), *Detect* with progress and
    *Stop* (`detectToolPath`) listing the candidates with state, version and
    source to *Use*, and the application's help panel while the tool is not
    usable.
  - `action`: `ForgeActionEditor` — the action's button with progress, *Stop*
    and result (`runAction`), or the flow's (`startFlow`).
  - `status`: `ForgeStatusEditor` — `statusOf`, followed through
    `watchStatus`, its items capped.
  - `date`, `time`, `dateTime`: `ForgeDateTimeEditor` with Material's date
    and time pickers within the setting's bounds, *Clear* when none is a
    value.
- **More from the existing kinds:** a colour opens a colour picker
  (`showForgeColorPicker`: saturation and brightness area, hue and opacity
  sliders, swatches, hex); a choice with a choices provider, and a string
  map's values with one, load at run time (`ForgeDynamicChoiceField`:
  *Loading…*, *None*, reloaded on the provider's changes); a choice that
  allows none offers *None*; a string map shows its default key first with
  its label (never removed) and normalises typed keys; an `int` or `double`
  with a `scale` shows the value in the shown unit and stores it scaled
  (`ForgeScaledNumberField`).
- **Behaviour widgets:** `ForgeHookButton` (a hook run with progress bar or
  spinner, message, *Stop*, result; confirmation first when the action asks
  one), `forgeHookButtonFor` (an action or a flow by id), `ForgeStatusView`,
  `ForgeStatusLevelIcon`, `ForgeSettingActionsBar`, and the flow runner
  (`showForgeFlowDialog` / `ForgeFlowDialog`: each step's title, message,
  link and code to copy, text / secret / one-time code fields, choices,
  waiting with polling, errors, *Cancel*).
- **The tile:** draws a section's groups (`ForgeSettingsGroup`) as headers
  with their help that fold the settings below them (`collapsed` starts
  folded); draws every setting's own actions (`ForgeSetting.actions`) under
  its editor; settings that keep no value get no reset button and the entry
  key `#<id>` (`forgeSettingEntryKey`); a result asking for a refresh reads
  the setting's state, choices and status again.
- `ForgeSettingEditorRequest` adds `values`, `refresh` / `requestRefresh`
  and `buildHelpPanel`; `ForgeConfigurationScope`, `ForgeConfigurationTile`
  and `forgeConfigurationTiles` take a `buildHelpPanel`
  (`ForgeHelpPanelBuilder`).
- `ForgeConfigurationUiTexts`: the new strings (`forge.configuration.ui.*`).
- The `[CU` trail logs the hook runs from the UI: actions and flows (run,
  outcome, steps), checks and detections, choices and fonts read, status
  reads and stream updates, catalogue reads, captures, refreshes.

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

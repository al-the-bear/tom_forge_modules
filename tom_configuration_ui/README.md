# Tom Configuration UI

The configuration tiles of the Forge kit. Every component with options
describes them (`tom_forge_core`'s `ForgeConfigurationDescription`: sections
of typed settings); the kit collects the descriptions of the registered
modules and keeps the values through its state-store port
(`tom_forge_kit`'s `ForgeConfigurationValues`). This package draws a section
as a **tile**, always the same way; **where the tiles go is the
application's decision** — a side panel's list, a page of tiles in a `Wrap`
or a grid, a layout of its own.

It depends on the kit, the shared look (`tom_forge_shared_ui`),
`tom_flutter_ui` (the form fields and their style) and `tom_core_kernel`
(the text resources), never on the panel shell.

## Using it

```dart
final values = ForgeConfigurationValues(
  api.stateStore,
  descriptions: forgeConfigurationDescriptionsOf(api),
);
await values.load();

// The application arranges the tiles.
Wrap(
  spacing: 16,
  runSpacing: 16,
  children: [
    for (final tile in forgeConfigurationTiles(values))
      SizedBox(width: 380, child: tile),
  ],
);
```

`ForgeConfigurationTile(section: ..., values: ...)` draws one section;
`forgeConfigurationTiles(values)` makes the tiles of every section of the
values' descriptions, ordered by `ForgeSettingsSection.order`. What a tile is
not given it takes from the nearest `ForgeConfigurationScope`: the values,
the editor registry, the style, the application's path picker
(`ForgePathPicker`), the icon resolver and the application's help panels
(`ForgeHelpPanelBuilder`).

Give the values service the hooks the settings name (actions, flows,
detectors, choices providers, status providers, action catalogues: the
kit's `forgeConfigurationHooksOf(api)`, or a `ForgeSettingHooks` of the
application's own); the editors run them through it:

```dart
final values = ForgeConfigurationValues(
  api.stateStore,
  descriptions: forgeConfigurationDescriptionsOf(api),
  hooks: forgeConfigurationHooksOf(api),
);
```

## The tile

The section's title (with its icon, and its help behind a button), then each
entry the description shows (`visibleWhen`). A setting has its label, its
editor (beside the label for a switch or a colour, below it otherwise), the
buttons of its own actions (`ForgeSetting.actions`, with progress and
result), its help on request, a **reset to default** button (enabled while a
value is stored or a refused one is shown; none for an action or a status,
which keep no value) and, under the editor, the reason a value was refused —
one the user typed (nothing is written) or one the store held (the default is
in effect). A group (`ForgeSettingsGroup`) is a header with its help that
folds the settings below it (`collapsed`: folded at first). An action whose
result asks for a refresh makes the setting's editors read their state,
choices and status again. A setting whose `enabledWhen` does not hold is
shown disabled. Every value the user makes is validated at once and written
through the values service; a value changed elsewhere (another window, a
reset) is shown.

`ForgeConfigurationTileStyle` is what every tile shares: `padding`,
`spacing` (between settings), `headerSpacing`, `dense`, `borderRadius`,
`borderWidth`, `showHeader` (off where the application shows the title
itself), `showIcons`, `fieldFamily` (Material or Cupertino fields) and
`formStyle` (the `tom_flutter_ui` form style of the fields);
`ForgeConfigurationTileStyle.compact` is the dense preset. Colours come from
the theme: `ForgeShellTheme`'s panel surface and divider when installed, else
the colour scheme.

## The editors

`ForgeSettingEditorRegistry` maps a setting kind (`ForgeSetting.kind`) to a
`ForgeSettingEditor` (a builder, whether it goes beside the label, its
width there). `ForgeSettingEditorRegistry.standard()` holds:

| Kind | Editor |
| --- | --- |
| `bool` | a switch (`TomFormFieldFamily.boolSwitch`), beside the label |
| `int` | a number field (`intInput`), the unit after it; with a `scale`, the value in the shown unit, stored scaled |
| `double` | a number field (`doubleInput`, the setting's decimals), the unit after it; with a `scale` as `int` |
| `string` | a text field (`stringInput`); several lines for a multiline setting |
| `choice` | the choices side by side (`stringSegmented`, up to three) or a list (`stringPicker`), **None** first when allowed; with a choices provider a list read at run time (*Loading…* while it reads) |
| `stringList` | with choices, chips to pick (`stringMultiSelect`); else the items as chips with a field to add one |
| `path` | a text field with **Browse…**, which opens the application's picker |
| `color` | a swatch with the hex value (`#RRGGBB`, `#AARRGGBB`) and a colour picker (area, hue, opacity, swatches), beside the label |
| `stringMap` | one row per entry (key, value free, chosen, or read per key from a provider), the default key first with its label, with a row to add one (keys normalised) |
| `fontFamily` | the name with a searchable font picker: suggestions, the provider's fonts in their own font, generic families, *Default font*, *Fixed-width fonts only* for a code font |
| `keyBinding` | a key capture field: click, press a combination; *Escape* cancels, *Clear* unbinds |
| `keyChord` | the same, strokes one after the other, ended by *Done* or the most strokes |
| `keyBindingTable` | the catalogue's actions with their bindings, grouped, a search box, conflicts marked, per-row capture, reset, removal and *Bind for every editor*, **Reset all** |
| `toolPath` | the path with **Browse…**, **Check again**, its state line (the detector's check), **Detect** (progress, *Stop*, candidates with state, version and source to **Use**) and the application's help panel while the tool is not usable |
| `action` | the button of its action (progress, *Stop*, result) or its flow (a dialog) |
| `status` | the status line its provider answers, followed while it streams, items capped |
| `date`, `time`, `dateTime` | the value with Material's date and time pickers within the bounds, **Clear** when none is a value |

A new kind of setting is a `ForgeSetting` subclass with its own kind id plus
an editor registered under it (`registry.copy()..register(kind, editor)`); an
application may register another editor for a standard kind the same way. An
editor gets a `ForgeSettingEditorRequest` (the setting, the value in effect,
`onChanged`, the resolved label, a field id, the style, whether it is
enabled, the error text, the path picker, the values service, the refresh
signal and the help panels); `ForgeSettingTomField` makes an editor of any
`tom_flutter_ui` field, and the behaviour widgets below make the rest. A
setting whose kind has no editor is shown with a message saying so.

## Behaviour: hooks, actions and flows

A description is const data and names its behaviour by id; the application
supplies the hooks at run time, and the editors run them through the values
service (`runAction`, `startFlow`, `checkToolPath`, `detectToolPath`,
`choicesFor`, `statusOf` / `watchStatus`, `catalogueOf`). A hook the
registry lacks is shown as such (*Not available here.*), never a crash.

The widgets an editor of a new kind can reuse: `ForgeHookButton` (runs a
hook with its progress — a bar when it reports how far it is, else a spinner
— its message, *Stop*, and its result; asks the action's confirmation
first), `forgeHookButtonFor` (the button of an action or a flow by id),
`ForgeStatusView` and `ForgeStatusLevelIcon`, `ForgeSettingActionsBar`,
`ForgeKeyCaptureField`, `ForgeDynamicChoiceField`, `showForgeFontPicker` and
`showForgeColorPicker`.

**Flows** (`ForgeSettingFlow`: signing in with OAuth, a one-time code) are
driven by `showForgeFlowDialog`: each step's title and message, a link and a
code to copy, the fields of an input step (text, secret, one-time code of a
given length), its choices (default *Continue*) and *Cancel*; a waiting step
shows progress and polls the session after its `pollAfter`; a refused answer
comes back with its error. The done step's result is the button's result
(and its value is written by the values service).

## Labels

Every label, help text, choice and message is a `ForgeText` (a resource key
with its English fallback), resolved through Tom Core's text resources
(`ForgeConfigurationLabels`: the installed `TomTextResourceProvider`
bundle, looked up as `TomFormLabels` and `TomCtr` do, else the fallback). The
tiles re-read their labels when the application installs another bundle
(`TomTextResourceProvider.appResourcesRevision`). The package's own strings
are `ForgeConfigurationUiTexts` (`forge.configuration.ui.*`); the validation
messages are `tom_forge_core`'s `ForgeConfigurationTexts`
(`forge.configuration.validation.*`).

An application installs its bundle at start. `tom_flutter_ui`'s fields
cannot be built without one, so a tile shown before any bundle is installed
installs an empty one (every label then shows its fallback).

## Icons

A section names its icon as data (`ForgeIconRef`, a code point of an icon
font). Flutter's builds shrink the icon fonts to the constant icons they find
and refuse an `IconData` made at run time, so the tiles draw icons from
constants only: `forgeMaterialIconFor` knows the Material icons a settings
section commonly uses, and an application with others passes its own
`ForgeConfigurationIconResolver`. An icon no resolver knows is left out.

## Debug trail

`kConfigurationUiDebug = true` (switchable at run time, before the first tile
is built) prints the edits, commits and refusals, resets, the hook runs from
the UI (actions and flows with their steps, checks and detections, choices,
fonts, status reads and stream updates, catalogue reads, captures, refreshes)
and the tiles mounted and disposed with the prefix `[CU`, with a heartbeat
and the Flutter errors (`_agent_guidelines/debug_mode.md` of the repository).

License: BSD-3-Clause.

# Tom Forge Command Palette

Forge's command palette as a kit component: `ForgeCommandPalette` is a searchable list of the application's actions — those of the action registry and of the registered modules (`forgeKitModulesOf`), each with its shortcut — and of its own (close, Toggle Left / Right Panel, which call `onTogglePanel`, else run the application's `forge.toggleLeftPanel` / `forge.toggleRightPanel` actions). It depends on
the Forge kit (`tom_forge_kit`) only, with `tom_forge_core` for the panel locations it names, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeCommandPaletteModule()` is a `ForgeKitModule`: registered with an
application (`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it hands the palette over as a
`ForgeQuickOpenExtra` for the all and actions modes at priority 0. An
application asks the registry for the overlay (`forgeQuickOpenBuilderFor`)
when the user opens the command palette: with `tom_forge_quick_open`
registered too, quick open (priority 10) wins, so the palette is what an
application without quick open shows. An application may also build
`ForgeCommandPalette` itself.

License: BSD-3-Clause.

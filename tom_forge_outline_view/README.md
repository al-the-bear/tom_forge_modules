# Tom Forge Outline View

Forge's Outline view as a kit component: `ForgeOutlineView` shows the symbol tree of the active editor, from the outline providers registered with the application's outline manager (`DefaultOutlineManager`), refreshed when the active editor or a provider changes; "No outline available" without one. It depends on
the Forge kit (`tom_forge_kit`, with `tom_forge_core` for its types) only, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeOutlineViewModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi`, lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.outline`,
details, group `Outline`. The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

License: BSD-3-Clause.

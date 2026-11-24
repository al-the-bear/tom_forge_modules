# Tom Forge Output View

Forge's Output view as a kit component: `ForgeOutputView` shows the application's output channels: a channel picker, the selected channel's lines in their `[HH:MM:SS] [TYPE] text` form as they come, auto-scroll while at the bottom, and Clear. It depends on
the Forge kit (`tom_forge_kit`) only, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeOutputViewModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi`, lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.output`,
messages, group `Output`, order 10. The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

License: BSD-3-Clause.

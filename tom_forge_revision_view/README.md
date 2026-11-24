# Tom Forge Revisions View

Forge's Revisions view as a kit component: `ForgeRevisionView` shows the saved revisions of the active file (the workspace state's), newest first; a click opens one read-only through `ForgeKitApi.openFile` (its `?revision=` URI), and with an application that is a `ForgeRevisionRestorer` a revision can replace the file; its context menu also deletes one. It follows the active editor through `ForgeActiveEditorListenable` (else the focus and editor streams) and reloads when the file is saved. It depends on
the Forge kit (`tom_forge_kit`) only, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeRevisionViewModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi`, lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.revisions`,
navigation, group `Explorer`, order 1 (below the file explorer). The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

License: BSD-3-Clause.

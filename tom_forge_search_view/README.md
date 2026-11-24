# Tom Forge Search View

Forge's Search view as a kit component: `ForgeSearchView` searches the workspace with the kit's `ForgeSearchManager` as the user types (case, whole word, regex), streaming results grouped by file with their paths relative to the workspace folder. A click opens the match at its position through the application's `ForgeFileNavigator` (`forgeOpenFileAtOf`: without one, `ForgeKitApi.openFile` opens the file); the query is recorded in an application state that is a `ForgeSearchQueryState`. It depends on
the Forge kit (`tom_forge_kit`) only, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeSearchViewModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi` (`ForgeSearchView.forApi`; `workspaceRoot:`, else the state's
`ForgeWorkspaceRoot`), lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.search`,
navigation, group `Search`, order 10 (after the file explorer's group). The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

License: BSD-3-Clause.

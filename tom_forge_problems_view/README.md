# Tom Forge Problems View

Forge's Problems view as a kit component: `ForgeProblemsView` lists the analysis diagnostics of the kit's `ForgeDiagnosticManager` grouped by file, with severity filters, a search box (regex, whole word, case) and copy; its title counts them. A click opens the diagnostic's file at its position through the application's `ForgeFileNavigator` (`forgeOpenFileAtOf`: without one, `ForgeKitApi.openFile` opens the file). It depends on
the Forge kit (`tom_forge_kit`) only, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeProblemsViewModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi` (`ForgeProblemsView.forApi`), lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.problems`,
messages, group `Problems`, order 0. The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

License: BSD-3-Clause.

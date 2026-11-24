# Tom Forge Quick Open

Forge's quick open as a kit component: `ForgeQuickOpen` is the dropdown below an application's search field that searches, as the user types (case, whole word, regex), the open editors, the workspace files (breadth first, without excluded or git-ignored folders, as `ForgeSearchConfig` says), the actions with their shortcuts and the settings; in the actions mode only the actions, in the chord mode the second keys that complete a pending chord shortcut. It works on `ForgeKitApi` alone: the action registry and the actions of the registered modules (`forgeKitModulesOf`), the open editors of the state, the workspace folder of the state's `ForgeWorkspaceRoot` (else the file system's root). It depends on
the Forge kit (`tom_forge_kit`) only, with `tom_forge_core` for the search configuration and `tom_file_system` for the files it lists, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeQuickOpenModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it hands the overlay over as a
`ForgeQuickOpenExtra` for every mode (all, actions, chord) at priority 10
(`forgeQuickOpenPriority`), above the command palette's. The application asks
the registry for it (`forgeQuickOpenBuilderFor`) when the user opens quick
open and builds it with a `ForgeQuickOpenRequest`: the search field it hosts
(controller and focus node), the chord pending, and what to do when a file,
the help or the settings is opened (a file: `ForgeKitApi.openFile` unless the
request says otherwise). The panel shell shows it below its title bar's
search field; another application places it as it likes, or builds
`ForgeQuickOpen` itself.

License: BSD-3-Clause.

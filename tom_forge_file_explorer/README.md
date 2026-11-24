# Tom Forge File Explorer

Forge's file explorer as a kit component: `ForgeFileExplorerView` shows the workspace's file tree from a `TomFileSystem` (folders expand on a tap, files open on a double tap), with its own context menu — Open, Rename..., New File, New Folder, Delete — followed by the modules' entries for its rows (`ForgeContextMenuController`, kinds `ForgeContextTarget.explorerFileKind` / `explorerDirectoryKind`), drawn with the shared look (`tom_forge_shared_ui`). Files open through the application's `ForgeFileNavigator` (`forgeOpenFileAtOf`: without one, `ForgeKitApi.openFile`). Given a `ForgeExplorerSelection` it shares its selection and hovered row with the application, which reveals a file through it; given a `DefaultFileDecorationManager` it draws the decorations. It depends on
the Forge kit (`tom_forge_kit`), the shared look and `tom_file_system`, never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeFileExplorerModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi` (`ForgeFileExplorerView.forApi`: the file system, the file navigator and
the context menus; the folder `rootUri:`, else the state's `ForgeWorkspaceRoot`), lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.explorer`,
navigation, group `Explorer`, order 0 (the Revisions view joins its group). The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

License: BSD-3-Clause.

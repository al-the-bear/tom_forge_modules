# Tom Forge File Explorer

Forge's file explorer as a kit component: `ForgeFileExplorerView` shows the workspace's file tree from a `TomFileSystem` (folders expand on a tap, files open on a double tap), with its own context menu — Open, **Open With ▸** for a file with more than one editor (the editors of the application's `ForgeEditorPicker`, to open it in once, and **Set default for .ext ▸**, `forgeOpenWithMenuEntry`), Rename..., New File, New Folder, Delete — followed by the modules' entries for its rows (`ForgeContextMenuController`, kinds `ForgeContextTarget.explorerFileKind` / `explorerDirectoryKind`), drawn with the shared look (`tom_forge_shared_ui`). Files open through the application's `ForgeFileNavigator` (`forgeOpenFileAtOf`: without one, `ForgeKitApi.openFile`). Given a `ForgeExplorerSelection` it shares its selection and hovered row with the application, which reveals a file through it; given a `DefaultFileDecorationManager` it draws the decorations. It depends on
the Forge kit (`tom_forge_kit`), the shared look, `tom_file_system`, `tom_file_session` (the filter rules and presets) and `tom_basics` (`.gitignore` matching), never on the panel shell, so any
application on the kit can show it.

## Using it

`forgeFileExplorerModule()` is a `ForgeKitModule`: registered with an application
(`DefaultKitApi.registerModule`, the panel shell's
`DefaultShellApi.registerModule`), it makes the view at activation from the
application's `ForgeKitApi` (`ForgeFileExplorerView.forApi`: the file system, the file navigator,
the context menus and the editor picker; the folder `rootUri:`, else the state's `ForgeWorkspaceRoot`), lists it in `views` and hands its placement
hint over as a `ForgeViewContributionsExtra`: id `forge.view.explorer`,
navigation, group `Explorer`, order 0 (the Revisions view joins its group). The hint names no panel; the application maps it to its layout (the
panel shell: `forgeContributedPanelTabs`), or passes another hint
(`placement:`), or builds the view itself.

## Filter rules, the hidden count and registered roots (opt-in)

With none of the options below the explorer is Tom Forge's: folders are listed as they are opened, entries whose name starts with `.` are left out, there is no header or footer. Each option is a parameter of the constructor, of `ForgeFileExplorerView.forApi` and of `forgeFileExplorerModule`:

| Parameter | Default | What it does |
| --- | --- | --- |
| `filter` | null | The ordered rule list in force at the start (`ForgeFilter` of `tom_file_session`: `include` / `exclude` globs, extensions, hidden, gitignored and todo-sibling switches; **the last matching rule decides**, an entry no rule matches is shown). A filter that is one of `filterPresets`' (the same object) selects that preset. |
| `filterPresets` | null | The presets the filter button offers. With `filter` alone, `tom_file_session`'s built-ins (`ForgeBuiltInPresets.all`: All files, Text files, Tom quest folder); without `filter`, the first preset is in force. |
| `rootSwitcher` | false | The header's root switcher: the host's `rootUri` and the folders the user registers. |
| `pickFolder` | null | The platform's folder picker for *Add folder…*; without one the explorer asks for the folder's path. |
| `stateStore` | null (`forApi`: `ForgeKitApi.stateStore` when an option is set) | Where the registered roots, the root shown and each root's filter choice are kept. |
| `stateKey` | `forge.view.explorer` | The prefix of the store keys (`<stateKey>.roots`, `<stateKey>.filters`): one per explorer instance. |
| `walkLimit` | 50000 (`forgeExplorerWalkLimit`) | How many entries the filtering explorer's walk reads before it stops. |

**Filtering** (`filter` or `filterPresets` given): the header's filter button (its icon tinted while the rules are edited) lists the presets, **Edit rules…** (the rules as text, one per line, in the words the hidden list uses — `include: **/*.md`, `exclude extensions: png`, `hidden: hide`, ...; a line it cannot read refuses Apply) and **Show hidden entries**, which shows the hidden entries dimmed until switched off (not kept). The tree is drawn from **one bounded background walk** of the root, made again when the root, the filter or the files change through the explorer: a folder is shown when it is shown itself or anything below it is, a folder hidden as hidden or gitignored is not entered (`.git`, build output), and the walk stops after `walkLimit` entries — the footer then says *Stopped after N entries*, and a folder the walk did not finish is listed when it is opened. The footer's **N hidden** opens the list of the hidden entries with the rule that hid each (with *Show them* and *Edit rules…*); a folder whose filter hides something carries its own count. A filter that hides everything says *No entries match this filter (N hidden)*.

**The root switcher** (`rootSwitcher: true`): the header names the root shown; its menu lists the host's root and the registered ones (name and path), **Add folder…** (refused with a notice for a path that is no folder) and, for a registered root, **Remove from list**, which forgets it and touches nothing in the folder. Each root keeps its own filter choice.

The view's trail (`[FX]`, switched on with `kForgeFileExplorerDebug = true`) records the walks, the root and filter changes and what is restored.

License: BSD-3-Clause.

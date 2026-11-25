# Changelog

## Unreleased

- **Filter rules, the hidden count and registered roots, opt-in** (the file
  tree features of Webwork's Workspace browser, D36 §2–§4): `filter` and
  `filterPresets` (`tom_file_session`'s `ForgeFilter`, last match deciding,
  and its built-in presets) with a header filter button (presets,
  **Edit rules…** as text, **Show hidden entries**); the tree drawn from a
  bounded background walk (`walkLimit`, default 50000; the footer says
  *Stopped after N entries*); the footer's **N hidden** with the list of
  hidden entries and their rules, and a per-folder count; `rootSwitcher`
  with **Add folder…** (`pickFolder`, else a path prompt) and
  **Remove from list**; the roots, the root shown and each root's filter
  kept through the kit's state store (`stateStore`, `stateKey`). On the
  constructor, `ForgeFileExplorerView.forApi` and `forgeFileExplorerModule`;
  without them the explorer is unchanged. The `[FX]` trail
  (`kForgeFileExplorerDebug`).

- **Open With ▸** in a file row's context menu, after Open, for a file with
  more than one editor: built from the application's editor picker
  (`ForgeFileExplorerView.editorPicker`, `ForgeKitApi.editorPicker` for
  `forApi`) with the kit's `forgeOpenWithMenuEntry` — the editors to open
  the file in once and **Set default for .ext ▸**.

## 0.1.0

- `ForgeFileExplorerView`, moved out of `tom_forge_shell` onto the kit (it
  opens files through `ForgeOpenFileAt` and shares its selection through a
  `ForgeExplorerSelection` instead of the shell's layout controller and
  state), and `forgeFileExplorerModule()`, the module that contributes it
  with its placement hint.

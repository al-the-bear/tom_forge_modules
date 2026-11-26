## Unreleased

- `ForgeText.id(id, params: ...)`: a text reference without English (an id
  relative to its package, read under its owner's scope; an unresolved one
  shows its id). `ForgeText.fallback` is nullable; `ForgeText.isLiteral`.
  `ForgeTextResolver`: the interface a type below the kit holds its text
  resolver as.
- **The configuration description** (`src/configuration/`): what a
  component can be configured in, as data an application shows as it
  decides. `ForgeConfigurationDescription` (id, title, help, sections;
  `problems()` lists what is wrong with it for its author),
  `ForgeSettingsSection` (a tile's worth of settings: title, help,
  `ForgeIconRef`, order) and `forgeOrderedSections`; `ForgeSetting<T>` with
  its `ForgeSettingStorage` (a state-store key and a path inside its
  document), default, help, `visibleWhen` / `enabledWhen`
  (`ForgeSettingCondition`), `decode` / `encode` / `validate` / `read`; the
  kinds `ForgeSettingKinds` names — bool, int, double, string, choice,
  string list, path, colour, string map — each a subclass with its
  constraints; `ForgeText`, a label as a resource key with its English
  fallback and parameters, and `ForgeConfigurationTexts`, the validation
  messages. Pure Dart; `tom_forge_kit` keeps the values, and
  `tom_configuration_ui` draws the tiles.
- **Behaviour hooks** (`forge_setting_hooks.dart`): a setting names the
  behaviour it uses by id — `ForgeSetting.actions` (buttons beside it) and
  per kind a detector, a choices provider, a status provider or an action
  catalogue — and the application supplies it at run time in a
  `ForgeSettingHooks` registry (`has`, `ids`, `addAll`, `merged`;
  `problems(hooks:)` names the missing ones). The contracts:
  `ForgeSettingAction` (`run` → `ForgeActionResult`: success with an
  optional value to write and a refresh, failure, cancelled; confirmation,
  emphasis, `isEnabled`), `ForgeSettingDetector` (`check` and `detect` with
  `ForgeDetectionHints` — candidate paths, search roots, executable names,
  environment variables, `PATH`, depth — answering `ForgeDetectedCandidate`s
  with a level, version and reason), `ForgeChoicesProvider` (async, per
  entry key, with a change stream), `ForgeSettingStatusProvider` (`current`
  and an optional `watch` stream of `ForgeStatusInfo`), `ForgeActionCatalogue`
  (the `ForgeCatalogueAction`s a key binding table lists) and
  `ForgeSettingFlow` (a multi-step interaction the UI drives: a
  `ForgeFlowSession` answers `ForgeFlowStep`s — show with a URL or code,
  input fields including secrets and one-time codes, waiting with a poll,
  done — to `ForgeFlowResponse`s). Every contract has a `ForgeCallback…`
  form; a hook runs with a `ForgeSettingContext` (value, other settings,
  write, progress, cancellation, entry key).
- **Storage bindings** (`forge_setting_binding.dart`):
  `ForgeSettingStorage(key, binding: id)` keeps a setting in a
  `ForgeSettingBinding` the application supplies (`read`, `write`, `watch`,
  `flushed`) instead of the state store; `ForgeMemorySettingBinding` and
  `ForgeCallbackSettingBinding`; `ForgeSettingStorage.none()` for settings
  that keep no value; `location` and `documentId` carry the binding.
- **Sub-groups:** a section's entries are settings and `ForgeSettingsGroup`s
  (a header with settings under it); `ForgeSettingsSection.settings` lists
  every setting, `entries` and `groups` keep the structure. A setting's
  `companions` (a key binding table's deleted bindings) are found by
  `settingById` and checked by `problems()`.
- **New kinds**, each with Forge's stored format: `ForgeFontFamilySetting`
  (fonts from a provider, suggestions, generic families), the key bindings
  (`forge_key_bindings.dart`: `ForgeKeyStroke` and `ForgeKeyChord` as data,
  `ForgeKeyBindingSetting`, `ForgeKeyChordSetting`,
  `ForgeKeyBindingTableSetting` — rows from a catalogue with
  `forgeKeyBindingRows`, conflicts with `forgeKeyBindingConflicts` (same keys
  in overlapping scopes, chord prefixes, primary modifier per platform),
  wildcard `*.<suffix>` overrides, reset all; stored as
  `forge.shortcuts.overrides` / `chordOverrides` / `deletedBindings`),
  `ForgeToolPathSetting` (path, detector with hints, status, actions; the
  empty path is not stored, as `forge.tools.<id>.path`), `ForgeActionSetting`
  and `ForgeStatusSetting` (no value), `ForgeDateSetting`,
  `ForgeTimeSetting` and `ForgeDateTimeSetting` over the const values
  `ForgeDate`, `ForgeTimeOfDay` and `ForgeDateTime` (`YYYY-MM-DD`, `HH:MM`,
  ISO 8601). Int and double settings show a value scaled (`scale`,
  `toShown` / `fromShown`) in a `unit`; choices and string-map values may come
  from a `choicesProvider` with a nullable *none*; string maps normalise
  their keys (`ForgeMapKeyNormalizer.fileExtension`), lay the stored entries
  over the defaults (`mergeDefaults`) and keep a `defaultKey` (`*`), as
  `forge.files.typeDefaults`. `ForgeText.literal` is a runtime text no
  lookup translates.

- `ForgeContextMenuEntry.children` (a submenu: choosing the entry shows its
  children instead of running it, `hasChildren`) and `checked` (a checkable
  entry, drawn with a checkmark when true; null: not checkable). Both are
  optional; existing entries are unchanged.
- `ForgeContextMenuEntry`, `ForgeQuickPickItem` and `StatusBarAlignment`
  moved here from `tom_forge_shared_ui`: plain data that `tom_forge_kit`'s
  models and `tom_forge_shared_ui`'s widgets share, so neither depends on the
  other for it. `tom_forge_shared_ui` re-exports them where they were.
- `ForgeMenuLocation` is gone: nothing used it, and the menu locations Forge's
  shell and editors place actions in are `tom_editors_shared`'s
  `ForgeMenuLocation` (re-exported by `tom_forge_ui`), declared once with
  `ForgeAction`. Breaking: the next release is 3.0.0.
- `forgeLoadGitignores(fileSystem, {root})` walks a `TomFileSystem` instead
  of a host path (it was `forgeLoadGitignores(String rootPath)`), so the
  rules come from the same files the shell shows, on disk, in memory or on
  the web; links are not entered. Breaking: the next release is 3.0.0.
- `DefaultSearchManager` searches text files only: it skips build output,
  tool and version-control folders (`skippedFolderNames`), files over
  `maxFileSizeBytes` (2 MB) and files whose start does not look like text,
  and a file or folder it cannot read no longer ends the search.

## 2.0.0

- The file-system contract and its implementations moved to `tom_file_system`
  and the undo stack to `tom_undo`, both in `tom_ai/basics`, renamed
  `Tom`-prefixed (`TomFileSystem`, `TomMemoryFileSystem`,
  `TomLocalFileSystem`, `TomUndoStack`, `tomApplyAll`, …). `files.dart` and
  `io.dart` are gone, nothing is re-exported, and `FileChangeEvent`,
  `FileChangeType`, `WillSaveEvent` and `SaveReason` are `tom_file_system`'s
  `TomFileChangeEvent`, `TomFileChangeType`, `TomWillSaveEvent` and
  `TomSaveReason`.
- `forgeApplyWorkspaceEdit(fs, edit)` replaces the file system's
  `applyWorkspaceEdit`: a workspace edit is Forge's vocabulary, so applying
  it is Forge's too.
- `tom_forge_undo.dart` keeps `ForgeUndoManager`, `DefaultUndoManager` and
  the listenables; the stack is `package:tom_undo/tom_undo.dart`.

## 1.0.0

- Initial version.
- One undo/redo stack for the workspace, `TomUndoStack<E>` (also in the
  platform-neutral `tom_forge_undo.dart`): bounded, a push clears redo, and an
  entry is applied first and moved second, so a failed undo leaves the history
  as it was; synchronous and asynchronous application, and `popNewest` for
  merging an act into the one before it. `tomApplyAll` and
  `tomApplyAllAsync` apply a composite step atomically, putting back what
  they applied when an item throws. `DefaultUndoManager` and
  `CompositeUndoEntry` run on them, as do the editors' histories and
  `tom_flutter_ui`'s `TomUndoHistory`.
- `forgeLoadGitignores(root)`: the walk that reads every `.gitignore` under a
  folder (never entering `.git` or a folder already ignored) into one
  `tom_basics` `TomGitignoreSet`, which holds the rules; Forge parses none
  itself.
- One file-system contract, `TomFileSystem`, addressed by `Uri` with a
  root: revision-checked atomic writes, `stat`, `readSlice`, `create`,
  `rename`, `trash`, and a watch that can be told which folders not to enter.
  `TomMemoryFileSystem` and, in `io.dart`, `TomLocalFileSystem` implement
  it, the latter with per-folder watching on Linux, the freedesktop.org trash
  and the Windows Recycle Bin. `files.dart` is the browser-safe entry point.
  The previous string-based `read`/`write`/`readBytes`/`createDirectory` and
  `MemoryFileSystem` are gone, and so are `EventBatcher` and the
  `maxWatcherPaths`, `watcherBatchWindow` and `maxConcurrentFileOps`
  settings, which only the removed `RealFileSystem` read.
- `DefaultSearchManager` searches any `TomFileSystem`, walking it from the
  root.

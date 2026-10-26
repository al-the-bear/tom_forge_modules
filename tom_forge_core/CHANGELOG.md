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

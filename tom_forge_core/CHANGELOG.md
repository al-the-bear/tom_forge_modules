## 1.0.0

- Initial version.
- One file-system contract, `ForgeFileSystem`, addressed by `Uri` with a
  root: revision-checked atomic writes, `stat`, `readSlice`, `create`,
  `rename`, `trash`, and a watch that can be told which folders not to enter.
  `ForgeMemoryFileSystem` and, in `io.dart`, `ForgeLocalFileSystem` implement
  it, the latter with per-folder watching on Linux, the freedesktop.org trash
  and the Windows Recycle Bin. `files.dart` is the browser-safe entry point.
  The previous string-based `read`/`write`/`readBytes`/`createDirectory` and
  `MemoryFileSystem` are gone, and so are `EventBatcher` and the
  `maxWatcherPaths`, `watcherBatchWindow` and `maxConcurrentFileOps`
  settings, which only the removed `RealFileSystem` read.
- `DefaultSearchManager` searches any `ForgeFileSystem`, walking it from the
  root.

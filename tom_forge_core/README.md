<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

Tom Forge's core: the types, service contracts and defaults the shell is
built from, in pure Dart, and the one file-system contract with its in-memory
and local implementations.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## File systems

One contract, `ForgeFileSystem`, that every read and write goes through —
the shell's editors and explorer, and Webwork's workspace browser — addressed
by `Uri`. A file system has a `root`; `uriOf` and `pathOf` map a path relative
to it to a `Uri` and back.

- **`package:tom_forge_core/files.dart`** — the contract and its values
  (`ForgeFileEntry`, `ForgeFileRevision`, `ForgeFileContent`,
  `ForgeFileConflict`, `ForgeFileChange`), the shared base
  (`ForgeFileSystemBase`: text reads and writes, `save` with its will-save and
  did-save events, `applyWorkspaceEdit` all or nothing), the in-memory
  `ForgeMemoryFileSystem` and the text test `forgeLooksLikeText`. It reaches
  no `dart:io` and no Flutter, so a browser build links it; a dart2js compile
  and a walk of its imports hold that on every test run.
- **`package:tom_forge_core/io.dart`** — `ForgeLocalFileSystem` over a folder
  on disk, with the platform parts it stands on.

What the contract guarantees, on every implementation:

- **Revision-checked writes.** `read` answers the bytes with the revision
  they were read at (size and SHA-256); `write` with an `expected` revision is
  refused with a `ForgeFileConflict` when the file is no longer that revision,
  so a change made by someone else is never written over.
- **Atomic writes.** The local file system writes a temporary file beside the
  target and renames it over it; a crash leaves the old file or the new one,
  never half of either.
- **Containment.** A symbolic link that leaves the root is listed, marked
  (`linkLeavesRoot`) and never followed.
- **Trash.** `trash` moves to the platform's trash — Finder's on macOS; on
  Linux `gio trash`, `trash-put`, or with neither the freedesktop.org home
  trash written directly (`forgeXdgTrash`); on Windows the Recycle Bin through
  the shell's `SHFileOperationW` (`forgeWindowsRecycle`) — and answers false
  where there is none (the in-memory file system), so the caller can offer a
  permanent `delete` instead.
- **Watching.** `watch` reports changes below the root, or is null where the
  platform does not watch. On macOS and Windows it is the platform's recursive
  watch; on Linux, where `Directory.watch` is not recursive, every folder is
  watched on its own (`ForgeDirectoryWatches`), a folder that appears is
  watched as it appears, and a folder the caller's `descend` excludes is never
  entered.
- **Slices.** `readSlice` reads at most a given number of bytes from a file's
  start or end, cut at a whole line — how a growing log is followed.

The editing session, the tree filter and the `.env` codec built on the
contract are `tom_forge_files`.

### Checking it on Linux and Windows

`tool/platform_check/run.sh` runs the parts that differ per platform from
this machine alone, in Docker:

- **linux** — `tool/platform_check/check.dart` on the Linux Dart VM (atomic
  writes, a stale revision refused, the watch one folder down and in a folder
  made later, the trash), then this package's suite, whose watch tests run
  only on Linux.
- **windows** — the same check on the Windows Dart VM under Wine: atomic
  writes and the Recycle Bin call. Wine reports no file-system events to Dart,
  so the watch is printed as not measured there.

It is started by hand and writes its logs to `testlog/platform_check/`.

### `.gitignore` rules

`forgeLoadGitignores(root)` reads every `.gitignore` under a folder into one
`TomGitignoreSet` from `tom_basics` (`package:tom_basics/utilities.dart`),
which parses and applies the rules; Forge's part is only the walk. The root's
file comes first and deeper ones later, so a nested file decides inside its
folder. The walk never enters `.git` or a folder the rules already ignore, and
passes over a file it cannot read.

```dart
final rules = await forgeLoadGitignores('/path/to/workspace');
if (rules.isIgnored('build/output.js', isDirectory: false)) {
  // skip it
}
```

## Context-menu contributions

The pure-Dart model behind the shell's context menus
(`src/types/forge_context_menu.dart`):

- `ForgeContextTarget` — what a menu is opened on: a **kind** the producer
  owns (`forge.explorer.file`, `<module>.<unit>`), opaque **data**, and the
  target's own **items** (`ForgeContextMenuItem`: commands only the producer
  can perform, drawn after the contributed entries).
- `ForgeContextMenuContribution` — a module's declaration that one of its
  actions, named by id, is an entry at targets of a kind: `isApplicable`
  (absent when false), `label` and `unavailableReason` (disabled, with the
  reason as tooltip) all read the target. The shell resolves the action from
  its registry and runs it with the target under
  `ForgeContextTarget.parameterKey`.

The drawing lives in `tom_forge_ui` (`ForgeContextMenuController`,
`ForgeContextTargetProvider`). See the repository guideline
`_copilot_guidelines/context_menu_contributions.md`.

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.

## Undo and redo

One stack, `ForgeUndoStack<E>`, that every undo history in the workspace runs
on — the shell's `DefaultUndoManager`, the text, Markdown, YAML and Dart
editors, the file tabs' `ForgeFileSession`, and `tom_flutter_ui`'s
`TomUndoHistory`. It is in **`package:tom_forge_core/tom_forge_undo.dart`**,
which reaches no `dart:io` and no Flutter, beside the `ForgeUndoManager`
contract and `DefaultUndoManager`.

- **Applied first, moved second.** `undo` and `redo` apply an entry and only
  then move it between the stacks, so an application that throws leaves the
  entry where it was and the error reaches the caller. `undoAsync` and
  `redoAsync` do the same for an application that completes later.
- **Bounded.** A push clears the redo stack and drops the oldest entries
  beyond `maxEntries`; `popNewest` takes the newest entry back so a history can
  merge a burst of typing into one act.
- **Atomic composite steps.** `forgeApplyAll` (and `forgeApplyAllAsync`)
  apply a list of steps in order and, when one throws, put back the ones
  already applied, newest first, before rethrowing. `CompositeUndoEntry`, the
  unit a `beginUndoGroup` / `endUndoGroup` block becomes, is built on it.

```dart
final history = ForgeUndoStack<String>(maxEntries: 50);
history.push('typed "hello"');
history.undo((entry) => print('undo $entry')); // applied, then moved to redo
history.redo((entry) => print('redo $entry'));
```

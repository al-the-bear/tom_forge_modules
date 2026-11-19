# tom_forge_office_editors

The office editors as Forge editor types. One module, `ForgeOfficeEditorsModule`,
opens office files itself (before the shell reads them as text) and offers two
editors under *Open With*:

| Choice id | Editor | What it is |
| --- | --- | --- |
| `office.lok` | `ForgeOfficeEditor` | the LibreOfficeKit editor (`tom_office_editor`'s `TomOfficeEditor`): the installed LibreOffice in a helper process, `tom_office_host` — the default |
| `office.zetaoffice` | `ForgeZetaOfficeEditor` | ZetaOffice (LibreOffice compiled to WebAssembly) in a webview (`TomZetaOfficeView`), the comparison route |

| Extensions (any case) | Kind (`ForgeOfficeKind`) | Native choice's label |
| --- | --- | --- |
| `.docx` `.odt` `.doc` `.rtf` | `document` | LibreOffice Writer (native) |
| `.xlsx` `.ods` `.xls` `.csv` | `spreadsheet` | LibreOffice Calc (native) |
| `.pptx` `.odp` `.ppt` | `presentation` | LibreOffice Impress (native) |

`.csv` is text: the module offers its editors for it under *Open With* only,
and `openUri` leaves it to the plain-text editor (`handles` answers false).

License: BSD-3-Clause. Not published (`publish_to: none`). Desktop only: a
helper process, a local content server for ZetaOffice. LibreOffice is never
bundled; ZetaOffice's files are downloaded at run time after the user
confirms (see `tom_office_editor`'s `THIRD_PARTY.md`).

## Usage

```dart
final shell = ...; // the Forge shell (ForgeShellApi)
final office = ForgeOfficeEditorsModule()..activate(shell);
(shell.modules as DefaultModuleRegistry).register(office);
```

The module is registered before the file editors and keeps *Plain Text
Editor* out of *Open With* for office files with `office.handles(uri)`; that
composition is `tom_forge_app`'s (`composeForgeSuite`).

## How it fits the shell

- **Opening.** `openUri` takes an office file with a local (`file:`) path in
  the shell's file system — the helper needs a path, so a file of a file
  system without local paths is declined. It shows an editor of this module
  already open on the file, else opens the editor the file-type default for
  the extension names (`office.lok` when none does). `editorChoicesFor`
  gives both choices; each opens its editor once per file, so a file may be
  open in both routes. ZetaOffice runs in one tab at a time (a second tab
  says so).
- **Host.** `ForgeOfficeHost` implements `TomOfficeEditorHost`: the file's
  path and `TomBinaryFiles` (`TomBinaryFileAccess` on local files), the
  helper launcher the module holds for the current LibreOffice, the shell's
  notifications for notices, the shell's `openExternal` for links, the
  shell's file picker for *Insert image*.
- **Detection and the helper.** At activation the module detects LibreOffice
  with `TomLibreOfficeDetector` and the user's path setting
  `forge.tools.libreoffice.path` (`ForgePreferencesService.externalToolPath`,
  empty: search), and makes a `TomOfficeProcessLauncher` with
  `tom_office_host` from `$TOM_BINARY_PATH/<platform>/`. Without the helper
  in the binaries layer a start fails with that reason. Leftovers of dead
  helpers are cleaned up once (`TomOfficeProcessLauncher.cleanUp`).
- **Save, undo, redo, dirty.** `getContent()` is null and the editors list
  the save action: an explicit save goes to the controller (LibreOfficeKit:
  temporary target, replace over an unchanged file, else the conflict
  banner; ZetaOffice: `store()` and the bytes posted back, a failed save
  leaving the document dirty); an automatic save leaves them alone. Undo and
  redo go to the controller; `isActionEnabled` follows `canUndo` /
  `canRedo` (LibreOfficeKit: `STATE_CHANGED .uno:Undo` / `.uno:Redo`;
  ZetaOffice: its undo manager); `isDirty` is the controller's (the engine's
  modified flag). History changes fire `onStateChanged`.
- **Clipboard.** The LibreOfficeKit editor routes the shell's copy, cut and
  paste (text) to the helper. Find is LibreOffice's own (Cmd+F opens its
  Find & Replace dialog); the shell's find bar is not offered.
- **Kept view state.** `saveState` keeps the part shown (sheet or slide;
  `{route: lok, part}`) and `restoreState` returns a reopened tab there once
  the document is open. The zoom and the scroll position are the view's own
  and are not exposed by `tom_office_editor`.
- **Outside changes.** `replaceContent` answers false, so the shell closes
  and reopens the editor (a new helper, an empty history). When the window
  regains focus, every editor checks its file (`checkExternal`): a clean
  document reopens, a dirty one shows the conflict.
- **Views.** The LibreOfficeKit editor's split copy is a second
  `TomOfficeEditor` on the same controller (one document, one history, its
  own viewport, no ribbon). ZetaOffice's copy says *This view cannot be
  split* with a button that shows the document.
- **Close.** A closed editor ends its helper (LibreOfficeKit) or closes its
  page and content site and frees the ZetaOffice slot.

## The tab when LibreOffice is missing

An office file opens a `ForgeOfficeEditor` tab whatever detection found.
Without a `found` result the tab shows detection's state panel
(`TomOfficeDetectionView`), one per state:

| State | The panel offers |
| --- | --- |
| `missing`, `tooOld` | the download link, *Choose LibreOffice…*, *Check again* |
| `damaged` | the reason, *Check again* |
| `quarantined` | *Open LibreOffice*, *Check again* |

- **Open with ZetaOffice** is offered below it (it needs no installed
  LibreOffice), unless ZetaOffice's files are not cached and the CDN does not
  answer (offline).
- **Choose LibreOffice…** stores the picked app as the path setting and runs
  detection again. **Check again** runs detection again; the panel turns into
  the editor in place once it reports `found`.
- **Open With** leaves `office.lok` out while detection reports no usable
  LibreOffice; `office.zetaoffice` stays. Opening the file again shows the
  tab with the panel.

## External Tools

The module's `externalTools` is `ForgeLibreOfficeTool`: the first row of the
Configuration panel's *External Tools* section (`id` `libreoffice`, the
setting `forge.tools.libreoffice.path`, an app bundle, the download page).
Its `check` runs `TomLibreOfficeDetector` with the user's path (none: the
start-up search), *Auto-detect* the detector's wider search; detection's
states map one to one onto `ForgeToolState`.

## Undo conformance

Both editors run Forge's undo conformance harness
(`test/undo_conformance_test.dart`, the subjects in the test-support package
`tom_forge_office_editors_testing`) against fakes that model the engines'
undo behaviour: a scripted LibreOffice helper (`ScriptedOfficeHelper`: text
committed by the input method or typed as keys, one undo step each, a new
edit ends the redo, the modified flag false whenever undo or redo reaches
the saved state) and a scripted ZetaOffice page (the same history and
flag). The evaluation's engine checks found LibreOffice 26.8.3.1 and
ZetaOffice clearing the flag that way. The fakes check the routing, not the
engines themselves. Skips, with their reasons (full conformance is decided
after the comparison,
`officeproto31h`):

| Check | `ForgeOfficeEditor` (LibreOfficeKit) | `ForgeZetaOfficeEditor` |
| --- | --- | --- |
| `dirtyFollowsSavedState` | **runs** | **runs** |
| `caretAfterUndoAndRedo` | skipped: the caret is the engine's, no text offset to compare; LibreOffice restores it | skipped: the caret is ZetaOffice's, inside the webview |
| `typingUndoneWithinPause` | skipped: LibreOffice groups typing itself; `forgeTypingPause` does not reach it | skipped: ZetaOffice groups typing itself |
| `noRedoAfterTyping` | **runs** | **runs** |
| `splitCopiesShareHistory` | **runs** | skipped: a webview page cannot be shown twice |
| `replaceContentClearsHistory` | skipped: `replaceContent` answers false; the reopen is tested by `FOFF-REOPEN-1` | skipped: same, `FZO-REOPEN-1` |

## Debug mode

`kForgeOfficeDebug` in `lib/src/forge_office_trail.dart`, prefix `[FO]`, off
by default and switchable at run time: activation and detection (state,
version, path setting or search), `openUri` taken or declined, the choice
opened or reused, the file-type default applied, save (with its outcome),
undo, redo, copy, cut and paste routed, `checkExternal` on focus, the state
panel shown, *Check again*, *Choose LibreOffice…*, the tool's checks, the
editor closed. Errors in the module's callbacks are reported through
`FlutterError.reportError` with the flag off too. The editors' own trails are
`tom_office_editor`'s `kOfficeEditorDebug` (`[OE]`) and `kZetaOfficeDebug`
(`[ZO]`).

## Tests

```sh
testkit :test
```

`test/office_editors_module_test.dart` (the module in a shell over a memory
file system, scripted helpers and ZetaOffice pages: opening, the choices,
save and undo routing, reopening, focus, the missing-LibreOffice panel, kept
state), `test/libreoffice_tool_test.dart` (the External Tools descriptor and
its row) and `test/undo_conformance_test.dart`.

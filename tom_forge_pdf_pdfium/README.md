# tom_forge_pdf_pdfium

Forge's PDFium editor adapter: the PDFium editor (`tom_pdf_editor`'s
`TomPdfEditor` over `tom_pdf_pdfium`'s `PdfiumEngine`) as a Forge editor over
the kit, and the kit module that opens `.pdf` files in it.

| Choice id | Editor | What it is |
| --- | --- | --- |
| `pdf.pdfium` | `ForgePdfEditor` | the PDFium editor: native rendering, annotations, form filling — the default for `.pdf` |

License: BSD-3-Clause. Not published (`publish_to: none`). Desktop only:
PDFium over FFI. It depends on `tom_forge_kit`, `tom_pdf_editor` and
`tom_pdf_pdfium`, never on the shell, a webview or pdf.js: an application
that takes only this adapter has PDFs without `flutter_inappwebview` and
without pdf.js's assets. The pdf.js view is the adapter
`tom_forge_pdf_pdfjs`.

## Usage

```dart
final pdf = ForgePdfiumModule(
  openExternal: environment.openExternal, // links of the document
);
api.registerModule(pdf); // a DefaultKitApi, or the panel shell's API
```

The module is a `ForgeKitModule`: any application of the kit activates it
with its `ForgeKitApi` (the panel shell's `DefaultShellApi.registerModule`, a
`DefaultKitApi`'s `registerModule`). Keep a plain-text editor out of *Open
With* for PDFs with `pdf.handles(uri)`.

## How it fits the kit

- **Opening.** `openUri` takes a `.pdf` (any case) of the application's file
  system, before the application reads it as text. It shows a PDF editor
  already open on the file (its own, or one of another PDF engine module: a
  module offering a `pdf.*` choice for the file); else, when the file-type
  default for `.pdf` names another module's choice (`pdf.pdfjs`), it opens
  the file in that choice; else in the PDFium editor. `editorChoicesFor`
  gives the `pdf.pdfium` choice, which opens one editor per file. Editors go
  where the application places them (`api.editorHost.showEditor`).
  A file with a local (`file:`) path is read and saved through the module's
  `TomBinaryFiles` on that path; a file of a file system without local paths
  through `TomFileSystemBinaryFiles` over the application's file system (the
  constructor's `fileSystemFiles` gives another): PDFium opens it from its
  bytes and saves into bytes.
- **Host.** `ForgePdfHost` implements `TomPdfEditorHost`: the file's
  `TomBinaryFiles` and path, the engine status (`engineStatus`: PDFium as
  `TomPdfiumLocator` finds it in the binaries layer, a `TomPdfiumLibrary`)
  and the engine (`PdfiumEngine.acquire`), the kit's notifications for
  notices, the module's `openExternal` for links (none given: links are not
  opened), the annotation author from the login name.
- **Save, undo, redo, dirty.** `getContent()` is null and the editor lists
  `forge.file.save`: an explicit save goes to the controller (temporary
  target, replace over an unchanged file, else the conflict banner); an
  automatic save leaves it alone. Undo and redo go to the controller;
  `isActionEnabled` follows `canUndo` / `canRedo`; `isDirty` is the
  controller's (the annotation and form history's saved marker). History
  changes fire `onStateChanged`.
- **Find and copy.** The editor is a `ForgeFindTarget`: Cmd+F inside the
  editor runs the application's Find action (`forgeFindActionId`), whose bar
  searches the document (match case, whole word, previous / next, the
  count); the editor's own find bar stays hidden. Closing the bar clears the
  search. The editor copies the selected text.
- **Kept view state.** `saveState` keeps the page, the offset into it and the
  zoom (`{route: pdfium, page, offset, zoom}`); `restoreState` returns a
  reopened tab there once the document has loaded.
- **Outside changes.** `replaceContent` answers false, so the application
  closes and reopens the editor (a new controller, an empty history). When
  the window regains focus every editor checks its file (`checkExternal`): a
  clean document reopens, a dirty one shows the conflict banner. The focus
  comes from the module's `windowFocusRegained` stream (the panel shell's
  `systemState.onWindowFocusChanged` where focused, say), by default from the
  app lifecycle returning to *resumed* (`AppLifecycleListener.onResume`);
  `checkExternalChanges()` runs the check at any time.
- **Views.** The split copy is a second `TomPdfEditor` on the same controller
  (one document, one history, its own viewport).
- **Close.** A closed editor gives its document and its share of the engine
  up.

## Undo conformance

The editor runs Forge's undo conformance harness
(`test/undo_conformance_test.dart`, the subject in the test-support package
`tom_forge_pdf_pdfium_testing`) against the base component's fake engine. The
checks speak of text; the subject maps typing to adding a note, and the
document's text to the notes' texts. Skips, with their reasons (full
conformance is decided after the comparison, `officeproto24`):

| Check | `ForgePdfEditor` (PDFium) |
| --- | --- |
| `dirtyFollowsSavedState` | **runs** |
| `caretAfterUndoAndRedo` | skipped: not applicable, annotations have no caret |
| `typingUndoneWithinPause` | skipped: not applicable, nothing is typed into the document (a note's text is one step) |
| `noRedoAfterTyping` | **runs** |
| `splitCopiesShareHistory` | **runs** |
| `replaceContentClearsHistory` | skipped: `replaceContent` answers false; the reopen is tested by `FPDF-REOPEN-1` |

## Debug mode

`kForgePdfiumDebug` in `lib/src/forge_pdf_trail.dart`, prefix `[FP]`, off by
default and switchable at run time: `openUri` taken or declined, the choice
opened or reused, the file-type default applied, save, undo, redo and find
routed, `checkExternal` on focus, links, the editor closed. Errors in the
module's callbacks are reported with the flag off too. The editor's own
trail is `tom_pdf_editor`'s `kPdfEditorDebug` (`[PE]`).

## Tests

```sh
testkit :test
```

The suites run in a bare kit (`ForgePdfTestKit`: a `DefaultKitApi` with an
editor host that reports to the kit state), no shell:
`test/pdfium_module_test.dart` (the module over a memory file system and the
fake engine), `test/find_state_remote_test.dart` (find, kept view state, a
file system without local paths), `test/narrow_test.dart` and
`test/undo_conformance_test.dart`. The suite that runs the PDFium and pdf.js
modules together is `tom_forge_pdf_pdfjs`'s.

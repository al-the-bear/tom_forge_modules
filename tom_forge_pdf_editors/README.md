# tom_forge_pdf_editors

The PDF editors as Forge editor types. One module, `ForgePdfEditorsModule`,
opens `.pdf` files itself (before the shell reads them as text) and offers two
editors under *Open With*:

| Choice id | Editor | What it is |
| --- | --- | --- |
| `pdf.pdfium` | `ForgePdfEditor` | the PDFium editor (`tom_pdf_editor`'s `TomPdfEditor`): native rendering, annotations, form filling — the default |
| `pdf.pdfjs` | `ForgePdfJsEditor` | Mozilla's pdf.js in a webview (`TomPdfJsView`), the comparison route; it opens in `components` mode, and the tab's actions *pdf.js view: components / integrated / full* switch it (DPPJ-5) |

License: BSD-3-Clause. Not published (`publish_to: none`). Desktop only:
PDFium over FFI, a local content server for pdf.js.

## Usage

```dart
final shell = ...; // the Forge shell (ForgeShellApi)
final pdf = ForgePdfEditorsModule()..activate(shell);
(shell.modules as DefaultModuleRegistry).register(pdf);
```

`composeForgeSuite` registers it before the file editors, and keeps *Plain Text
Editor* out of *Open With* for PDFs with `pdf.handles(uri)`; that composition
is `tom_forge_app`'s.

## How it fits the shell

- **Opening.** `openUri` takes a `.pdf` (any case) of the shell's file system;
  it shows an editor of this module already open
  on the file, else opens the editor the file-type default for `pdf` names
  (`pdf.pdfium` when none does). `editorChoicesFor` gives both choices; each
  opens its editor once per file, so a file may be open in both routes.
  A file with a local (`file:`) path is read and saved through the module's
  `TomBinaryFiles` on that path; a file of a file system without local paths
  through `TomFileSystemBinaryFiles` over the shell's file system (the
  constructor's `fileSystemFiles` gives another): PDFium opens it from its
  bytes and saves into bytes, pdf.js gets the bytes through its content site.
- **Host.** `ForgePdfHost` implements `TomPdfEditorHost` (and so the pdf.js
  view's `TomPdfViewHost`): the file's `TomBinaryFiles` and path, PDFium
  from the binaries layer (`TomPdfiumLocator`, `PdfiumEngine.acquire`), the
  shell's notifications for notices, the shell's `openExternal` for links,
  the annotation author from the login name.
- **Save, undo, redo, dirty.** `getContent()` is null and the editors list
  `forge.file.save`: an explicit save goes to the controller (temporary
  target, replace over an unchanged file, else the conflict banner); an
  automatic save leaves them alone. Undo and redo go to the controller;
  `isActionEnabled` follows `canUndo` / `canRedo`; `isDirty` is the
  controller's (PDFium: the annotation and form history's saved marker; pdf.js:
  its annotation storage). History changes fire `onStateChanged`.
- **Find and copy.** Both editors are `ForgeFindTarget`s: `editor.find` and
  Cmd+F inside the editor open the shell's find bar, which searches the
  document (match case, whole word, previous / next, the count); the editors'
  own find bars stay hidden. Closing the bar clears the search. The PDFium
  editor copies the selected text.
- **Kept view state.** `saveState` keeps the page, the offset into it and the
  zoom (PDFium; `{route: pdfium, page, offset, zoom}`) or the page and the
  scale (pdf.js; `{route: pdfjs, page, scale}`); `restoreState` returns a
  reopened tab there once the document has loaded. A pdf.js mode switch keeps
  the position.
- **Outside changes.** `replaceContent` answers false, so the shell closes
  and reopens the editor (a new controller, an empty history). When the
  window regains focus, every editor checks its file (`checkExternal`): a
  clean document reopens, a dirty one shows the conflict banner.
- **Views.** The PDFium editor's split copy is a second `TomPdfEditor` on
  the same controller (one document, one history, its own viewport). The
  pdf.js editor's copy says *This view cannot be split* with a button that
  shows the main view.
- **Close.** A closed editor gives its document and its share of the engine
  up (PDFium) or closes its page and content site (pdf.js).

## Undo conformance

Both editors run Forge's undo conformance harness
(`test/undo_conformance_test.dart`, the subjects in `lib/testing.dart`) against
the base components' fakes: the fake PDFium engine and a scripted pdf.js page.
The checks speak of text; the subjects map typing to adding a note, and the
document's text to the notes' texts. Skips, with their reasons (full
conformance is decided after the comparison, `officeproto24`):

| Check | `ForgePdfEditor` (PDFium) | `ForgePdfJsEditor` |
| --- | --- | --- |
| `dirtyFollowsSavedState` | **runs** | skipped: pdf.js's `annotationStorage` stays modified after undoing back to the saved state (no saved marker) |
| `caretAfterUndoAndRedo` | skipped: not applicable, annotations have no caret | skipped: not applicable |
| `typingUndoneWithinPause` | skipped: not applicable, nothing is typed into the document (a note's text is one step) | skipped: not applicable, pdf.js groups its own editing |
| `noRedoAfterTyping` | **runs** | **runs** |
| `splitCopiesShareHistory` | **runs** | skipped: a webview page cannot be shown twice |
| `replaceContentClearsHistory` | skipped: `replaceContent` answers false; the reopen is tested by `FPDF-REOPEN-1` | skipped: same, `FPDFJS-REOPEN-1` |

## Debug mode

`kForgePdfDebug` in `lib/src/forge_pdf_trail.dart`, prefix `[FP]`, off by
default and switchable at run time: `openUri` taken or declined, the choice
opened or reused, the file-type default applied, save, undo, redo and find
routed, `checkExternal` on focus, the mode switch, the editor closed. Errors
in the module's callbacks are reported with the flag off too. The editors'
own trails are `tom_pdf_editor`'s `kPdfEditorDebug` (`[PE]`, `[PE:js]`).

## Tests

```sh
testkit :test
```

`test/pdf_editors_module_test.dart` (the module in a shell over a memory file
system, the fake engine and scripted pdf.js pages) and
`test/undo_conformance_test.dart`.

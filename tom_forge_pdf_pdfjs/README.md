# tom_forge_pdf_pdfjs

Forge's pdf.js editor adapter: the pdf.js view (`tom_pdf_pdfjs`'s
`TomPdfJsView`, Mozilla's pdf.js in a webview) as a Forge editor over the
kit, and the kit module that offers it under *Open With* for `.pdf` files.

| Choice id | Editor | What it is |
| --- | --- | --- |
| `pdf.pdfjs` | `ForgePdfJsEditor` | pdf.js in a webview, offered under *Open With*; it opens in `full` mode, pdf.js's own viewer (`ForgePdfJsEditor.defaultMode`, DPEV-5), and the tab's actions *pdf.js view: components / integrated / full* switch it; a kept view state reopens the tab in its mode |

License: BSD-3-Clause. Not published (`publish_to: none`). Desktop only: a
local content server serves pdf.js and the document to the webview. It
depends on `tom_forge_kit`, `tom_pdf_editor` (the view host every PDF view
shares) and `tom_pdf_pdfjs`, never on the shell or PDFium. The PDFium
editor, the default for `.pdf`, is the adapter `tom_forge_pdf_pdfium`.

## Usage

```dart
final pdfium = ForgePdfiumModule(openExternal: environment.openExternal);
final pdfJs = ForgePdfJsModule(openExternal: environment.openExternal);
api
  ..registerModule(pdfium) // the default editor for .pdf
  ..registerModule(pdfJs); // offered under Open With
```

The module is a `ForgeKitModule`: any application of the kit activates it
with its `ForgeKitApi`. It is an editor choice, not the default: `openUri`
takes a `.pdf` only when the file-type default for `.pdf` names `pdf.pdfjs`
(when the PDFium module is asked first, it opens the file in this choice
too); every other `.pdf` is the default editor's. Keep a plain-text editor out of *Open With*
for PDFs with `pdfJs.handles(uri)`.

## How it fits the kit

- **Opening.** `editorChoicesFor` gives the `pdf.pdfjs` choice for a `.pdf`
  (any case) of the application's file system; it opens one editor per file,
  where the application places it (`api.editorHost.showEditor`), so a file
  may be open in both routes. A file with a local (`file:`) path is read and
  saved through the module's `TomBinaryFiles` on that path; a file of a file
  system without local paths through `TomFileSystemBinaryFiles` over the
  application's file system: pdf.js gets the bytes through its content site.
- **Host.** `ForgePdfJsHost` implements `TomPdfViewHost` (no engine: pdf.js
  renders in the page): the file's `TomBinaryFiles` and path, the kit's
  notifications for notices, the module's `openExternal` for links (none
  given: links are not opened), the annotation author from the login name.
- **Save, undo, redo, dirty.** `getContent()` is null and the editor lists
  `forge.file.save`: an explicit save goes to the controller, which writes
  the file and reopens the document; an automatic save leaves it alone. Undo
  and redo go to the page; `isActionEnabled` follows `canUndo` / `canRedo`;
  `isDirty` follows pdf.js's annotation storage. History changes fire
  `onStateChanged`.
- **Find.** The editor is a `ForgeFindTarget`: Cmd+F in the page or the
  toolbar runs the application's Find action (`forgeFindActionId`), whose bar
  searches the document through pdf.js's find controller; the view's own
  find field stays hidden. Closing the bar clears the search.
- **Modes and kept view state.** `setMode` switches between `components`,
  `integrated` and `full` (a dirty document is not switched: a notice says to
  save first); the position is kept. `saveState` keeps the mode, the page
  and the scale (`{route: pdfjs, mode, page, scale}`); `restoreState`
  reopens the tab in its mode, then at its page and scale once loaded.
- **Outside changes.** `replaceContent` answers false, so the application
  closes and reopens the editor. When the window regains focus every editor
  checks its file (`checkExternal`): a clean document reopens, a dirty one
  shows the conflict banner. The focus comes from the module's
  `windowFocusRegained` stream, by default from the app lifecycle returning
  to *resumed*; `checkExternalChanges()` runs the check at any time.
- **Views.** A webview page cannot be shown twice: the split copy says *This
  view cannot be split* with a button that shows the main view.
- **Close.** A closed editor closes its page and its content site.

## Undo conformance

The editor runs Forge's undo conformance harness
(`test/undo_conformance_test.dart`, the subject in the test-support package
`tom_forge_pdf_pdfjs_testing`) against a scripted pdf.js page. Skips, with
their reasons (decided after the comparison, `officeproto24`):

| Check | `ForgePdfJsEditor` |
| --- | --- |
| `dirtyFollowsSavedState` | skipped: Forge reopens the document after a save, so pdf.js's history starts again and nothing can be undone past the save. Undoing back to the saved state does read clean (`FPDFJS-DIRTY-1`) |
| `caretAfterUndoAndRedo` | skipped: not applicable |
| `typingUndoneWithinPause` | skipped: not applicable, pdf.js groups its own editing |
| `noRedoAfterTyping` | **runs** |
| `splitCopiesShareHistory` | skipped: a webview page cannot be shown twice |
| `replaceContentClearsHistory` | skipped: `replaceContent` answers false; the reopen is tested by `FPDFJS-REOPEN-1` |

## Debug mode

`kForgePdfJsDebug` in `lib/src/forge_pdfjs_trail.dart`, prefix `[FPJ]`, off
by default and switchable at run time: `openUri` taken, the choice opened or
reused, save, undo, redo and find routed, `checkExternal` on focus, the mode
switch, links, the editor closed. Errors in the module's callbacks are
reported with the flag off too. The view's own trail is `tom_pdf_editor`'s
`kPdfEditorDebug` (`[PE:js]`).

## Tests

```sh
testkit :test
```

The suites run in a bare kit (`ForgePdfJsTestKit`), no shell, the webview
replaced by a scripted page: `test/pdfjs_module_test.dart` (the module, and
the PDFium and pdf.js modules together as an application composes them:
both choices, PDFium the default, the default naming pdf.js, an open PDF
editor shown again), `test/find_state_test.dart`, `test/narrow_test.dart`
and `test/undo_conformance_test.dart`.

## The routes' evaluation

`tool/evaluation/` is the evaluation harness that compares the two PDF
routes (PDFium, and pdf.js in its three modes) on macOS: a Flutter app of
its own (`tom_forge_pdf_route_evaluation`) over `tom_pdf_editor`,
`tom_pdf_pdfium` and `tom_pdf_pdfjs`. It is a development tool, not part of
this package's dependencies; see its README.

# Office routes evaluation harness

The evaluation of Forge's two office routes for the office/PDF prototype: the
LibreOfficeKit editor (`lok`: `TomOfficeEditor` over `tom_office_host` and the
installed LibreOffice) and ZetaOffice in the webview (`zetaoffice`:
`TomZetaOfficeView`), measured the same way over the public sample set. It
implements the office part of `part-evaluation` of the working document
`_ai/quests/tom_forge/ideas/office_and_pdf_integration_prototype/office_and_pdf_integration_prototype.docspecs.md`.

It is a small macOS Flutter app (`tom_forge_office_route_evaluation`, not
sandboxed, like Forge's debug and profile builds) whose integration test is
the harness, run in a profile build with `flutter drive --profile`, and a
Python runner (standard library only) for the references and the comparisons.

## Running it

On mbp, after `samples/fetch_samples.py` has fetched the sample files, with
the screen unlocked and the evaluation window visible (it comes to the front
when it starts; WebKit gives ZetaOffice's page animation frames only while a
person can see it):

```bash
cd tom_forge/tom_forge_office_editors/tool/evaluation
python3 run_evaluation.py                   # references, three runs, comparison
python3 run_evaluation.py --runs 1 --edit-minutes 1   # a quick check
python3 run_evaluation.py --only zetaoffice --skip-references
python3 run_evaluation.py --skip-drive      # the comparison again
```

`run_evaluation.py`:

1. compiles `pdfkit_tool.swift` (PDFKit: page sizes, renders and the pixel
   comparison; an image of the harness window);
2. makes the older formats (`report.doc`, `sheet.xls`, `deck.ppt`) from the
   core files with desktop LibreOffice;
3. makes the fidelity references of every core file: desktop LibreOffice's PDF
   export (`soffice --convert-to pdf`, a profile of its own), Quick Look's
   rendering (`qlmanage -t`) and Microsoft Word, Excel and PowerPoint's PDF
   export, driven by AppleScript into each app's own container (they are
   sandboxed). Excel is not asked for `.ods`: it opens an ODS file behind a
   modal dialog that blocks the automation;
4. runs `integration_test/office_routes_test.dart` once per run: the
   LibreOfficeKit route, then ZetaOffice;
5. compares the routes' PDF exports with the references, and the saved files
   of the roundtrips with the originals; adds the install sizes and the code
   size; writes `results/summary-office.yaml` (the medians over the runs).

The scratch folder is `ztmp/office_evaluation_work/` of the workspace (the
copies, the exports, the references, the drive logs); it is deleted at the
start of a run unless `--skip-references` or `--skip-drive` is given.

## What it measures

| Measure | `lok` | `zetaoffice` |
| --- | --- | --- |
| 1 Opening fidelity (run 1) | the route's own PDF export (`save` with format `pdf` in a helper of its own: the layout the tiles show), the first three pages rendered by PDFKit at 1.5 px/pt, against desktop LibreOffice's and Microsoft Office's exports and Quick Look's page 1; the window images of each file | the same with ZetaOffice's PDF export (`storeToURL` with the kind's PDF filter, the page's `exportPdf` hook) |
| 2 Save roundtrip (every run) | every core file and the older formats saved unchanged and after the scripted edit (a word at a text's start, into A1, into the first slide's first object); the runner reopens both in desktop LibreOffice: text (txt export), every sheet's values (CSV) and formulas, counts of paragraphs, tables, images, comments, tracked changes, sheets, slides, notes and masters, the package's parts | the same; the edit through UNO in the page (`editForTest`) |
| 3 Editing latency (every run) | 100 keystrokes into the middle of a paragraph of `report` and into a cell of `sheet`: key → LibreOffice's first callback → tile request → tile → frame, from the recorded helper channel (the `[OE]` trail's events, timestamped) | 100 keydown events dispatched to ZetaOffice's canvas, timed to the second animation frame after each, and whether the text reached the document |
| 3 Scrolling and zoom (every run) | `FrameTiming`s over a 10 s scripted scroll through `report` and `sheet-large`, and the ribbon's zoom from 50 % to its largest step (300 %); jank: build or raster over 16.7 ms | `requestAnimationFrame` intervals over 600 wheel events on the canvas, and Ctrl+wheel; jank: an interval over 25 ms |
| 4 Start (every run) | open time to the document open (accepting input) and to the first tile; the run's first open is the cold start | open time to ZetaOffice showing the document; the first is the cold start (the WebAssembly compiled) |
| 4 Memory | the footprint of this app and every helper after open and after scrolling (`report`, `sheet-large`, `deck`); after the editing session (run 1, `--edit-minutes`, default 10); three documents open: one helper each | this app and the WebKit content processes started for the tab |
| 5 Install and download size (run 1) | `LibreOffice.app`, the helper and its library; `tom_forge_app`'s bundle | the ZetaOffice download (bytes and time, into a scratch cache), the cache, the page's assets |
| 6 Crash isolation (run 1) | `kill -9` of the helper during an unsaved edit with a second document open: the tab's message, the other tab, what was lost, the reopen; every `damaged-*` file | the WebKit content process killed under an unsaved edit with a LibreOfficeKit tab open; every `damaged-*` file |
| 7 UI (run 1) | the dialog checklist (Character, Paragraph, Find and Replace, Page Style, Format Cells, the colour dialog through Format Cells, Insert Chart, Insert Table) opened with the ribbon control's command, in window mode and in JSON mode, an image of each with both modes side by side; the feature checklist from the ribbon model; the code size | the feature checklist (its own full interface; text input inside a Forge tab); the code size |
| 8 Engine checks (run 1) | the scripted helper's (`tom_forge_office_editors_testing`) modelled undo, redo, dirty and no-redo-after-typing against LibreOffice | the same against ZetaOffice |

A measure the harness cannot take is written as `measured: false` with the
reason; a measure that fails is written the same way with its error, and the
run goes on.

**What the fidelity numbers are.** Both routes are compared through their own
PDF export, the one place where a route's layout can be laid beside the
references page for page; the window images show the routes as a person sees
them. The automatic verdict per page (identical below 0.5 % of differing
pixels, minor below 5 %, major above) is the evidence; the verdict per file is
the comparison report's.

## Results

Written to `evaluation/results/` in the idea's folder:

- `lok/run-<n>.yaml`, `zetaoffice/run-<n>.yaml`, with the environment
  (machine, macOS, build mode, Flutter, LibreOffice and the helper, ZetaOffice,
  the Forge commit, whether the screen was locked); the runner adds
  `fidelity`, `install_size` and `ui_code_lines` to run 1 and
  `save_roundtrip_comparison` to every run;
- `<route>/screenshots/`: the window per core file, the dialogs (window and
  JSON mode side by side), and the fidelity pages with major differences
  (the route's page and the marked difference);
- `summary-office.yaml`.

## Not measured, by design

- **The Forge app bundle before and after the office packages:** it needs a
  second release build of `tom_forge_app` without them; the bundle with them is
  recorded.
- **Password-protected office files:** the sample set has none.
- **Shortcuts and focus inside a Forge tab (ZetaOffice):** WebKit takes the keys
  first; a person checks them.

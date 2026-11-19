# PDF routes evaluation harness

The evaluation of Forge's two PDF routes for the office/PDF prototype: the
PDFium editor and the pdf.js view in its three modes (`integrated`, `full`,
`components`), measured the same way over the public sample set. It
implements the PDF part of `part-evaluation` and `part-pdf-pdfjs`
§ *What the comparison with PDFium measures* of the working document
`_ai/quests/tom_forge/ideas/office_and_pdf_integration_prototype/office_and_pdf_integration_prototype.md`.

It is a small macOS Flutter app (`tom_forge_pdf_route_evaluation`, not
sandboxed, like Forge's debug and profile builds) whose integration test is
the harness, run in a profile build with `flutter drive --profile`.

## Running it

On mbp, after `samples/fetch_samples.py` has fetched the sample files:

```bash
cd tom_forge/tom_forge_pdf_editors/tool/evaluation
python3 run_evaluation.py              # crash probes, then three runs
python3 run_evaluation.py --runs 1     # one run
python3 run_evaluation.py --skip-probes
```

`run_evaluation.py` (standard library only):

1. compiles `pdfkit_tool.swift`, the macOS Preview side (PDFKit);
2. runs the PDFium route's crash probes: every `damaged-*` PDF, `pdf-encrypted`
   with and without its password, and 20 seeded corruptions of `pdf-text`,
   each opened, rendered and read (up to 20 pages) in a `flutter test`
   process of its own (`test/crash_probe_test.dart`), since PDFium runs inside
   Forge's process;
3. runs `integration_test/pdf_routes_test.dart` once per run: the PDFium
   route, then pdf.js in each mode;
4. writes `results/summary.yaml`, the medians over the runs, and the
   screenshots (`--skip-drive` makes both again from the scratch folder).

`--dart-define=EVAL_ONLY=pdfjs-components` (or a comma-separated list of
routes) runs some routes only, when the harness itself is being worked on.

## What it measures

| Measure | PDFium route | pdf.js route (each mode) |
| --- | --- | --- |
| Fidelity | pages of pdf-text, pdf-annot, pdf-form, pdf-scan, pdf-encrypted and pdf-long rendered by PDFium at 1.5 px/pt, compared with PDFKit (Preview) | the same pages rendered by pdf.js itself (`page.render`), compared with PDFKit and with the PDFium images |
| Open | open time and first page drawn for every sample (the first open of a route is its cold start) | the same, through the bridge and the page's own `data-loaded` mark |
| Search | the whole-document search of `reasoning` (pdf-text) and `depreciation` (pdf-long), first hit and done | pdf.js's find controller, done when every page has its matches |
| Scrolling and zoom | Flutter's `FrameTiming`s over a scripted scroll through pdf-long and pdf-huge and the zoom bar's 50 % → 400 % | `requestAnimationFrame` intervals in the page over a scripted scroll and a zoom from 0.5 to 4 |
| Memory | the app's physical footprint after open and after scrolling, on pdf-long and pdf-huge | the app and the WebKit content processes started during the route's run |
| Annotations | highlight, note and ink made through the controller, saved; incremental save checked (the original bytes a prefix); read back by PDFium, PDFKit and (in the pdf.js runs) pdf.js | highlight, ink and free text made with pdf.js's own editors, saved; read back by PDFium and PDFKit; PDFium's saved file read by pdf.js |
| Forms | a text field and a checkbox of pdf-form filled, saved, read back by PDFium, PDFKit and pdf.js | the same plus its combo box and list box; PDFium's filled form read by pdf.js |
| Crash isolation | `run_evaluation.py`'s probes | the damaged files opened in the view; the WebKit content process killed under an open document, then a reload |

A measure the harness cannot take is written as `measured: false` with the
reason; a measure that fails is written the same way with its error, and the
run goes on. Flutter errors reported during a route are listed under
`framework_errors` instead of failing it.

**Fidelity comparison.** `pdfkit_tool diff` counts the pixels whose largest
channel differs by more than 40 of 255 and that no pixel within one pixel of
the other image matches, both ways: a glyph placed a pixel apart is no
difference, missing or extra content is. The raw share without that
tolerance is kept too. Automatic verdicts: identical below 0.5 %, minor
below 5 %, major above; pages with major differences are kept as screenshots
(the route's image, the reference and the marked difference) in run 1. The
human verdict per file belongs to the comparison report.

**A locked screen.** With the screen locked macOS hides every window: WebKit
gives the page no animation frames and pdf.js does not draw. The harness then
stands in for `requestAnimationFrame` in the page and asks the viewer to draw
(`raf_stand_in` in the environment), and it reports no frame timings for
either route (`scrolling: measured: false`), since they would not be those
of a person watching. The scripted scrolls still run for the memory samples.
The evaluation app also turns off WebKit's window occlusion detection (an
SPI used only here, never in Forge) so that a covered window keeps drawing.

## Results

Written to `evaluation/results/` in the idea's folder:

- `<route>/run-<n>.yaml` for `pdfium`, `pdfjs-integrated`, `pdfjs-full` and
  `pdfjs-components`, with the environment (machine, macOS, build mode,
  Flutter, PDFium and pdf.js versions, the Forge commit, whether the screen
  was locked);
- `<route>/screenshots/`: one page per sample from run 1 as a small JPEG
  (the route's rendering and its marked differences from Preview and, for
  pdf.js, from PDFium), and full-size PNGs of every page with a major
  difference; `preview/screenshots/` holds Preview's renderings;
- `pdfium/crash-isolation.yaml`;
- `summary.yaml`.

The scratch folder is `ztmp/pdf_evaluation_work/` of the workspace (page
images, copies, the drive logs); it is deleted at the start of a run.

## Not measured, by design

- **Chrome's viewer:** headless Chrome draws its PDF viewer blank, so whether
  an annotation shows in it is a checklist item for a person.
- **pdf.js's stamp tool:** it asks for an image through a file dialog.
- **Memory after ten minutes of editing:** a PDF route has no editing session
  of that length; its edits are annotations and form fields.

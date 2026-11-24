# PDF routes evaluation harness

The evaluation of Forge's two PDF routes for the office/PDF prototype: the
PDFium editor and the pdf.js view in its three modes (`integrated`, `full`,
`components`), measured the same way over the public sample set. It
implements the PDF part of `part-evaluation` and `part-pdf-pdfjs`
§ *What the comparison with PDFium measures* of the working document
`_ai/quests/tom_forge/ideas/office_and_pdf_integration_prototype/office_and_pdf_integration_prototype.docspecs.md`.

It is a small macOS Flutter app (`tom_forge_pdf_route_evaluation`, not
sandboxed, like Forge's debug and profile builds) whose integration test is
the harness, run in a profile build with `flutter drive --profile`.

## Running it

On mbp, after `samples/fetch_samples.py` has fetched the sample files:

```bash
cd tom_forge/tom_forge_pdf_pdfjs/tool/evaluation
python3 run_evaluation.py              # crash probes, then three runs
python3 run_evaluation.py --runs 1     # one run
python3 run_evaluation.py --skip-probes
```

With the screen locked the runner stops before the runs, since they would
overwrite the results without frame timings; `--allow-locked-screen` runs
them anyway (see *A locked screen* below).

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

### The checks

`integration_test/pdf_checks_test.dart` takes the measures that are not
timed, once per route (PDFium, and pdf.js in each mode), into
`results/<route>/checks.yaml`:

- **engine checks against the fakes:** clean and nothing to undo after
  opening, an edit dirties and enables undo, undo enables redo, undo back to
  the saved state, a new edit ends the redo, a save clears dirty, each
  against what the undo-conformance fakes (`tom_forge_pdf_pdfium_testing`, `tom_forge_pdf_pdfjs_testing`)
  model; for PDFium also the saved annotation read back after reopening;
- **the feature checklist:** search, text selection, highlight, note, ink,
  free text, form filling (text fields, checkboxes, combo and list boxes),
  page thumbnails, and what of the route's own UI works inside a Forge tab;
- **pdf.js's dialog checklist:** document properties, print, the password
  prompt and the stamp's image picker, with a screenshot of each that opens
  (`results/<route>/screenshots/dialog-*.png`). Print and the image picker
  open system panels the harness cannot answer: whether they are offered is
  recorded, they are not triggered.

It runs with the screen unlocked and takes a few minutes:

```bash
flutter drive --profile -d macos --driver test_driver/integration_test.dart \
  --target integration_test/pdf_checks_test.dart \
  --dart-define=EVAL_SAMPLES=<samples/files> \
  --dart-define=EVAL_RESULTS=<results> --dart-define=EVAL_WORK=<scratch>
```

## What it measures

| Measure | PDFium route | pdf.js route (each mode) |
| --- | --- | --- |
| Fidelity | pages of pdf-text, pdf-annot, pdf-form, pdf-scan, pdf-encrypted and pdf-long rendered by PDFium at 1.5 px/pt, compared with PDFKit (Preview) | the same pages rendered by pdf.js itself (`page.render`), compared with PDFKit and with the PDFium images |
| Open | open time and first page drawn for every sample (the first open of a route is its cold start) | the same, through the bridge and the page's own `data-loaded` mark |
| Search | the whole-document search of `reasoning` (pdf-text) and `depreciation` (pdf-long), first hit and done | pdf.js's find controller, done when every page has its matches |
| Scrolling and zoom | Flutter's `FrameTiming`s over a scripted scroll through pdf-long and pdf-huge and the zoom bar's 50 % → 400 %; jank: build or raster over 16.7 ms | `requestAnimationFrame` intervals in the page over a scripted scroll and a zoom from 0.5 to 4; jank: an interval over 25 ms (`jank_threshold_ms`), since WebKit gives the page whole milliseconds and an on-time 60 Hz frame reads as 16 or 17 ms |
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
- **pdf.js's stamp tool and print:** they open the system's file dialog and
  print panel; the checks record that they are offered.
- **Memory after ten minutes of editing:** a PDF route has no editing session
  of that length; its edits are annotations and form fields.

## Re-run after the split (2026-11-24)

After the harness moved into this package, both test files were run again on
mbp with `flutter test integration_test/<file> -d macos` (a debug build, one
run, results into a scratch folder), the screen unlocked and the window
floating in front, under a load average of 30–70 from other work on the
machine. They were compared with the committed results (`summary.yaml`, the
medians of three profile runs; `run-1.yaml` per route; the checks in
`pdf-checks-officeproto31hc.yaml` and, for pdf.js's engine checks,
`pdf-checks-officeproto31hg.yaml`).

**Every pdf.js open timed out at first, with the screen unlocked.** The cause
was not the harness: `tom_pdf_pdfjs/third_party/pdfjs/6.5.438/build/`
(`pdf.mjs`, `pdf.worker.mjs`, …) was missing from the package. The
package's `.gitignore` line `build/` also ignores that folder, so it was never
committed and was lost when the repositories became independent clones. The
page loaded, `pdf.mjs` answered 404 and pdf.js never started. With the folder
put back, both files pass. The folder is committed now (tom_modules 2af7580,
byte-identical to the release zip); the rule reads `/build/`, and the
package's test `PDFJS-VENDOR-1` fails when a file is missing.

| Measure | Earlier | Now | Verdict |
| --- | --- | --- | --- |
| pdf.js open, every sample, every mode | all open; first page 0.4–2.2 s, pdf-huge 6.3–10.7 s | all open; first page 0.3–1.9 s, pdf-huge 7.8–8.8 s | match (within the run-to-run band) |
| pdf.js search | 135 / 444 hits; pdf-long 21–25 s | 135 / 444 hits; pdf-long 16–19 s | match |
| pdf.js text layer, fidelity verdicts (vs Preview, vs PDFium) | per file as in `run-1.yaml` | identical verdicts in every mode | match |
| pdf.js annotations (highlight, ink, free text; read back by PDFium and Preview; PDFium's file read) | all made, saved incrementally, read back | the same | match |
| pdf.js forms (text, checkbox, combo, list; read back) | all filled and read back | the same | match |
| pdf.js crash isolation | truncated file fails, corrupt opens, killed process reported, reload reopens | the same | match |
| pdf.js scrolling jank (pdf-long, pdf-huge) | 0.5–15.9 % | 0.3–15.7 % | match |
| pdf.js zoom jank | 28.8–35.6 % | 35.1–49.2 % | higher: the run shared the machine with a load average of 30–70 |
| pdf.js memory, total | 0.7–2.4 GB | 0.85–2.4 GB; the app process 100–200 MB more | the app's part: a debug build (`flutter test`) against profile builds |
| pdf.js asset size | 14,529,995 B | 14,530,236 B | match (the bridge grew by 241 B) |
| `pdf_checks_test`: engine checks, every route | no mismatch | no mismatch | match |
| `pdf_checks_test`: feature and dialog checklists | as committed | the same, except the search's match count | match: the count is read as soon as it is above 0, while the find still runs |
| PDFium open, search, annotations, forms, fidelity | as committed | the same; first page 1.2–2.2× slower | match; the slower first pages are the debug build |
| PDFium `pdf-encrypted` (and once `pdf-form`): page 1 drawn | timed out in committed runs 1 and 3 | timed out | the same intermittent wait, older than the split |

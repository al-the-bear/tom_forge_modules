# Changelog

## 0.1.0

- `ForgePdfJsEditor` (the pdf.js view as a Forge editor), its host
  `ForgePdfJsHost` and the kit module `ForgePdfJsModule` (choice
  `pdf.pdfjs`, offered under *Open With*), from `tom_forge_pdf_editors`,
  which is split by engine (CMP-9). Written against the kit: the module is a
  `ForgeKitModule`, the host reaches the application through `ForgeKitApi`,
  links go to the `openExternal` the application gives, outside changes are
  checked when the window regains focus (`windowFocusRegained`, by default
  the app lifecycle's resume). The view comes from `tom_pdf_pdfjs`; the host
  is a `TomPdfViewHost` (no engine).
- The debug flag is `kForgePdfJsDebug`, prefix `[FPJ]`.
- The PDF routes' evaluation harness (`tool/evaluation/`) is here, beside
  the comparison route.

# Changelog

## 0.1.0

- `ForgePdfEditor` (the PDFium editor as a Forge editor), its host
  `ForgePdfHost` and the kit module `ForgePdfiumModule` (choice
  `pdf.pdfium`, the default for `.pdf`), from `tom_forge_pdf_editors`, which
  is split by engine (CMP-9). Written against the kit: the module is a
  `ForgeKitModule`, the host reaches the application through `ForgeKitApi`
  (notifications, the find action, the editor host), links go to the
  `openExternal` the application gives, outside changes are checked when the
  window regains focus (`windowFocusRegained`, by default the app
  lifecycle's resume). The engine comes from `tom_pdf_pdfium`; the host's
  `engineStatus` is the located `TomPdfiumLibrary`.
- The debug flag is `kForgePdfiumDebug` (was `kForgePdfDebug`), prefix
  `[FP]`.

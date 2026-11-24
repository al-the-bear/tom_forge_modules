/// The PDFium editor as a Forge editor over the kit: [ForgePdfiumModule]
/// opens `.pdf` files (the default editor, choice `pdf.pdfium`) in
/// [ForgePdfEditor] over [ForgePdfHost] (PDFium from the binaries layer).
/// No shell, no webview, no pdf.js: the pdf.js view is the adapter
/// `tom_forge_pdf_pdfjs`. Desktop only (PDFium over FFI).
library;

export 'src/forge_pdf_editor.dart';
export 'src/forge_pdf_host.dart';
export 'src/forge_pdf_trail.dart' show kForgePdfiumDebug;
export 'src/forge_pdfium_module.dart';

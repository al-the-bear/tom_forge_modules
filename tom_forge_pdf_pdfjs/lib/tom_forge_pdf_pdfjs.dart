/// The pdf.js view as a Forge editor over the kit: [ForgePdfJsModule]
/// offers [ForgePdfJsEditor] (choice `pdf.pdfjs`, Mozilla's pdf.js in a
/// webview) under Open With for `.pdf` files, over [ForgePdfJsHost]. No
/// shell, no PDFium: the PDFium editor, the default for `.pdf`, is the
/// adapter `tom_forge_pdf_pdfium`. Desktop only (a local content server).
library;

export 'src/forge_pdfjs_editor.dart';
export 'src/forge_pdfjs_host.dart';
export 'src/forge_pdfjs_module.dart';
export 'src/forge_pdfjs_trail.dart' show kForgePdfJsDebug;

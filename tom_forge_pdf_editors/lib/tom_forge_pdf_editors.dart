/// The PDF editors as Forge editor types: [ForgePdfEditorsModule] opens
/// `.pdf` files and offers [ForgePdfEditor] (PDFium, `pdf.pdfium`, the
/// default) and [ForgePdfJsEditor] (pdf.js, `pdf.pdfjs`) under Open With,
/// over [ForgePdfHost]. Desktop only (PDFium over FFI, a local server).
library;

export 'src/forge_pdf_editor.dart';
export 'src/forge_pdf_host.dart';
export 'src/forge_pdf_trail.dart' show kForgePdfDebug;
export 'src/forge_pdfjs_editor.dart';
export 'src/pdf_editors_module.dart';

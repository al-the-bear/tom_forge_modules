/// The PDFium editor under Forge's undo conformance harness, with its skips
/// (listed with their reasons in the README): the annotation history on
/// TomUndoStack with a saved marker. The subject and fakes are the test
/// support's (`tom_forge_pdf_pdfium_testing`), so an app composing the
/// module runs the same checks.
library;

import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart';
import 'package:tom_forge_pdf_pdfium_testing/tom_forge_pdf_pdfium_testing.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

void main() {
  runForgeUndoConformance(
    'PDF editor (PDFium)',
    (saved) => ForgePdfEditorSubject(
      ForgePdfEditor(
        uri: forgePdfTestUri,
        host: forgePdfTestHost(saved),
        decoder: forgePdfTestDecoder,
      ),
    ),
    skip: forgePdfEditorSkips,
  );
}

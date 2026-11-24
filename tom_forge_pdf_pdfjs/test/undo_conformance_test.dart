/// The pdf.js editor under Forge's undo conformance harness, with its skips
/// (listed with their reasons in the README): pdf.js's own history, played
/// by a scripted page. The subject and fakes are the test support's
/// (`tom_forge_pdf_pdfjs_testing`), so an app composing the module runs the
/// same checks.
library;

import 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart';
import 'package:tom_forge_pdf_pdfjs_testing/tom_forge_pdf_pdfjs_testing.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

void main() {
  runForgeUndoConformance('pdf.js editor', (saved) {
    final page = ScriptedPdfJsPage([if (saved.isNotEmpty) saved]);
    return ForgePdfJsEditorSubject(
      ForgePdfJsEditor(
        uri: forgePdfJsTestUri,
        host: forgePdfJsTestHost(),
        channelForTesting: page,
        testBaseUri: forgePdfJsTestBaseUri,
      ),
      page,
    );
  }, skip: forgePdfJsEditorSkips);
}

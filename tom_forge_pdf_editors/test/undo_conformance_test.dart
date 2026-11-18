/// The PDF editors under Forge's undo conformance harness, with the skips
/// each route has (listed with their reasons in the README): the PDFium
/// editor (the annotation history on TomUndoStack with a saved marker) and
/// the pdf.js editor (pdf.js's own history, played by a scripted page). The
/// subjects and fakes are the package's (`testing.dart`), so an app
/// composing the module runs the same checks.
library;

import 'package:tom_forge_pdf_editors/testing.dart';
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';
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

  runForgeUndoConformance('pdf.js editor', (saved) {
    final page = ScriptedPdfJsPage([if (saved.isNotEmpty) saved]);
    return ForgePdfJsEditorSubject(
      ForgePdfJsEditor(
        uri: forgePdfTestUri,
        host: forgePdfJsTestHost(),
        channelForTesting: page,
        testBaseUri: forgePdfJsTestBaseUri,
      ),
      page,
    );
  }, skip: forgePdfJsEditorSkips);
}

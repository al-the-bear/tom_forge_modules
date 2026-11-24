# Tom Forge PDF pdf.js Testing

Test support for `tom_forge_pdf_pdfjs`: the pdf.js editor as an undo subject
(`ForgePdfJsEditorSubject`), with the checks it skips
(`forgePdfJsEditorSkips`), a scripted pdf.js page standing in for the webview
(`ScriptedPdfJsPage`, on `tom_pdf_pdfjs`'s `FakePdfJsChannel`) and a bare kit
without a shell (`ForgePdfJsTestKit`: a `DefaultKitApi` over an in-memory file
system, with an editor host that reports to the kit state). They describe
how to drive the editor for Forge's undo conformance harness
(`tom_forge_ui_testing`), so the adapter's own suite and an application's
suite run the same checks.

It depends on `flutter_test`, so it is a package of its own and is taken only
in `dev_dependencies`:

```yaml
dev_dependencies:
  tom_forge_pdf_pdfjs_testing:
    path: ../tom_forge_pdf_pdfjs_testing
```

```dart
import 'package:tom_forge_pdf_pdfjs_testing/tom_forge_pdf_pdfjs_testing.dart';
```

## License

BSD-3-Clause; see [LICENSE](LICENSE).

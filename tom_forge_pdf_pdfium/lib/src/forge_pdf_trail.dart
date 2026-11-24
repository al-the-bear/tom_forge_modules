import 'package:flutter/widgets.dart';

// ============================================================
// DEBUG MODE SWITCH — the PDFium editor in Forge (tom_forge_pdf_pdfium)
// ============================================================
// true  → event trail enabled (the editor's own trail, [PE], is
//         tom_pdf_editor's kPdfEditorDebug)
// false → no trail (errors are reported either way)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time (a host or a test sets it), like the YAML and
// Markdown editors' flags; off by default.
// ============================================================
bool kForgePdfiumDebug = false;

/// Logs a timestamped event (no-op while [kForgePdfiumDebug] is false). Filter:
/// `flutter run 2>&1 | grep '\[FP'`.
void forgePdfiumTrail(String event) {
  if (!kForgePdfiumDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FP $ts] $event');
}

/// Reports [error] through [FlutterError.reportError] with the trail on or
/// off, and logs it to the trail.
void forgePdfiumReport(Object error, StackTrace stack, String context) {
  forgePdfiumTrail('ERROR $context: $error');
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'tom_forge_pdf_pdfium',
      context: ErrorDescription(context),
    ),
  );
}

/// An [AppLifecycleListener] calling [onResume] each time the application
/// returns to *resumed* (on the desktop: the window regains focus); null,
/// with a trail entry, where no binding is running (a plain `test`).
AppLifecycleListener? forgePdfiumLifecycleListener(VoidCallback onResume) {
  try {
    WidgetsBinding.instance;
  } catch (_) {
    forgePdfiumTrail('no binding: outside changes are not checked on focus');
    return null;
  }
  return AppLifecycleListener(onResume: onResume);
}

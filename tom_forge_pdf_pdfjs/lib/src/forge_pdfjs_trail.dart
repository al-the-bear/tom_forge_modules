import 'package:flutter/widgets.dart';

// ============================================================
// DEBUG MODE SWITCH — the pdf.js editor in Forge (tom_forge_pdf_pdfjs)
// ============================================================
// true  → event trail enabled (the view's own trail, [PE:js], is
//         tom_pdf_editor's kPdfEditorDebug)
// false → no trail (errors are reported either way)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time (a host or a test sets it), like the YAML and
// Markdown editors' flags; off by default.
// ============================================================
bool kForgePdfJsDebug = false;

/// Logs a timestamped event (no-op while [kForgePdfJsDebug] is false).
/// Filter: `flutter run 2>&1 | grep '\[FPJ'`.
void forgePdfJsTrail(String event) {
  if (!kForgePdfJsDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FPJ $ts] $event');
}

/// Reports [error] through [FlutterError.reportError] with the trail on or
/// off, and logs it to the trail.
void forgePdfJsReport(Object error, StackTrace stack, String context) {
  forgePdfJsTrail('ERROR $context: $error');
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'tom_forge_pdf_pdfjs',
      context: ErrorDescription(context),
    ),
  );
}

/// An [AppLifecycleListener] calling [onResume] each time the application
/// returns to *resumed* (on the desktop: the window regains focus); null,
/// with a trail entry, where no binding is running (a plain `test`).
AppLifecycleListener? forgePdfJsLifecycleListener(VoidCallback onResume) {
  try {
    WidgetsBinding.instance;
  } catch (_) {
    forgePdfJsTrail('no binding: outside changes are not checked on focus');
    return null;
  }
  return AppLifecycleListener(onResume: onResume);
}

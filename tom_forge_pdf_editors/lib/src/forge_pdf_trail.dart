import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — PDF editors in Forge (tom_forge_pdf_editors)
// ============================================================
// true  → event trail enabled (the editors' own trails, [PE] / [PE:js],
//         are tom_pdf_editor's kPdfEditorDebug)
// false → no trail (errors are reported either way)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time (a host or a test sets it), like the YAML and
// Markdown editors' flags; off by default.
// ============================================================
bool kForgePdfDebug = false;

/// Logs a timestamped event (no-op while [kForgePdfDebug] is false). Filter:
/// `flutter run 2>&1 | grep '\[FP'`.
void forgePdfTrail(String event) {
  if (!kForgePdfDebug) return;
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
void forgePdfReport(Object error, StackTrace stack, String context) {
  forgePdfTrail('ERROR $context: $error');
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'tom_forge_pdf_editors',
      context: ErrorDescription(context),
    ),
  );
}

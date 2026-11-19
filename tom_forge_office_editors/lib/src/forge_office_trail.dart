import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — office editors in Forge (tom_forge_office_editors)
// ============================================================
// true  → event trail enabled (the editors' own trails, [OE] / [ZO], are
//         tom_office_editor's kOfficeEditorDebug / kZetaOfficeDebug)
// false → no trail (errors are reported either way)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time (a host or a test sets it), like the PDF editors'
// flag; off by default.
// ============================================================
bool kForgeOfficeDebug = false;

/// Logs a timestamped event (no-op while [kForgeOfficeDebug] is false).
/// Filter: `flutter run 2>&1 | grep '\[FO'`.
void forgeOfficeTrail(String event) {
  if (!kForgeOfficeDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FO $ts] $event');
}

/// Reports [error] through [FlutterError.reportError] with the trail on or
/// off, and logs it to the trail.
void forgeOfficeReport(Object error, StackTrace stack, String context) {
  forgeOfficeTrail('ERROR $context: $error');
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'tom_forge_office_editors',
      context: ErrorDescription(context),
    ),
  );
}

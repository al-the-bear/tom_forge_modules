import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — the ZetaOffice office editor in Forge
// (tom_forge_office_zetaoffice)
// ============================================================
// true  → event trail enabled (the view's own trail, [ZO], is
//         tom_office_zetaoffice's kZetaOfficeDebug; the LibreOfficeKit
//         adapter's is tom_forge_office_lok's kForgeOfficeDebug, [FO])
// false → no trail (errors are reported either way)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time (a host or a test sets it), like the PDF editors'
// flag; off by default.
// ============================================================
bool kForgeZetaOfficeDebug = false;

/// Logs a timestamped event (no-op while [kForgeZetaOfficeDebug] is false).
/// Filter: `flutter run 2>&1 | grep '\[FZO'`.
void forgeZetaOfficeTrail(String event) {
  if (!kForgeZetaOfficeDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FZO $ts] $event');
}

/// Reports [error] through [FlutterError.reportError] with the trail on or
/// off, and logs it to the trail.
void forgeZetaOfficeReport(Object error, StackTrace stack, String context) {
  forgeZetaOfficeTrail('ERROR $context: $error');
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'tom_forge_office_zetaoffice',
      context: ErrorDescription(context),
    ),
  );
}

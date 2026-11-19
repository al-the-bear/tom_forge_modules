import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — External Tools section (tom_forge_ui)
// ============================================================
// true  → event trail + heartbeat + FlutterError intercept enabled
// false → no trail (errors are reported either way)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time (a host or a test sets it), like the YAML and
// Markdown editors' flags; off by default because the trail's
// FlutterError.onError intercept replaces the host's handler.
// ============================================================
bool kForgeExternalToolsDebug = false;

/// Logs a timestamped event (no-op while [kForgeExternalToolsDebug] is
/// false). Filter: `flutter run 2>&1 | grep '\[FT'`. Paths are logged, no
/// other user data.
void externalToolsTrail(String event) {
  if (!kForgeExternalToolsDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FT $ts] $event');
}

/// Reports [error] through [FlutterError.reportError] with the trail on or
/// off, and logs it to the trail.
void externalToolsReport(Object error, StackTrace stack, String context) {
  externalToolsTrail('ERROR $context: $error');
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'tom_forge_ui (external tools)',
      context: ErrorDescription(context),
    ),
  );
}

import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — Dart Code Editor
// ============================================================
// true  → event trail + heartbeat + FlutterError intercept enabled
// false → zero-cost no-op (compiler eliminates all trace calls)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Flip to true whenever investigating freezes, unexpected rebuilds,
// lost actions, or any other hard-to-reproduce runtime behaviour.
// ============================================================

/// Master debug switch for the Dart code editor.
///
/// When `true`, [trailEvent] prints timestamped messages to the console.
/// Filter output with: `flutter run 2>&1 | grep '\[DE\]'`
const bool kDartEditorDebug = false;

/// Previous FlutterError handler saved during debug mode activation.
/// Restored on widget disposal.
FlutterExceptionHandler? dartEditorPrevFlutterErrorHandler;

/// Log a timestamped event to the console (no-op when [kDartEditorDebug] is false).
///
/// Console prefix: `[DE]`
///
/// Filter output:
/// ```bash
/// flutter run 2>&1 | grep '\[DE\]'
/// ```
void trailEvent(String event) {
  if (!kDartEditorDebug) return;
  final now = DateTime.now();
  final ts = '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[DE $ts] $event');
}

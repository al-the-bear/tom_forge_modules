import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — Markdown Editor Integration
// ============================================================
// true  → event trail enabled
// false → zero-cost no-op (compiler eliminates all trace calls)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Flip to true whenever investigating integration issues.
// ============================================================

/// Master debug switch for the markdown editor integration layer.
///
/// When `true`, [trailEvent] prints timestamped messages to the console.
/// Filter output with: `flutter run 2>&1 | grep '\[ME\]'`
///
/// Set to `true` at runtime to enable debug logging:
/// ```dart
/// kMdEditorIntegrationDebug = true;
/// ```
bool kMdEditorIntegrationDebug = false;

/// Log a timestamped event to the console (no-op when
/// [kMdEditorIntegrationDebug] is false).
///
/// Console prefix: `[ME]`
///
/// Filter output:
/// ```bash
/// flutter run 2>&1 | grep '\[ME\]'
/// ```
void trailEvent(String event) {
  if (!kMdEditorIntegrationDebug) return;
  final now = DateTime.now();
  final ts = '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[ME $ts] $event');
}

import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — YAML Editor component
// ============================================================
// Set to true to enable the event trail, heartbeat timer, and
// FlutterError intercept used for freeze/hang diagnosis. Off by
// default: the intercept replaces FlutterError.onError for every
// host the editor is embedded in, a test harness included.
//
// Non-const so it can be toggled at runtime (e.g. from tests
// or debug UI).
//
// See: tom_forge/_agent_guidelines/debug_mode.md
// ============================================================
bool kYamlEditorDebug = false;

/// Set to false to disable heartbeat output while keeping other debug logs.
bool kYamlEditorHeartbeat = false;

/// Lightweight event trail for freeze / hang diagnosis.
///
/// Every meaningful user action, controller operation, and focus change is
/// printed here via [debugPrint] **when [kYamlEditorDebug] is true**.
/// When [kYamlEditorDebug] is false this is a zero-cost no-op.
///
/// Filter the Flutter console with the `[YE]` prefix, e.g.:
///   flutter run 2>&1 | grep '\[YE\]'
void trailEvent(String event) {
  if (!kYamlEditorDebug) return;
  final now = DateTime.now();
  final ts = '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[YE $ts] $event');
}

/// Truncate a value for logging to avoid flooding console.
String trailTruncate(Object? value, [int maxLen = 60]) {
  var s = value.toString();
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen)}...';
}

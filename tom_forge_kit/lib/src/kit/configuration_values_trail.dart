import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — Configuration values (tom_forge_kit)
// ============================================================
// true  → event trail of reads, writes, binding changes and hook runs
// false → no-op (every trace call returns at once)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time. Flip to true whenever investigating lost writes,
// a binding that is not followed, or a hook (action, detector, choices,
// status, catalogue, flow) that does not answer.
// ============================================================
// ignore: prefer_const_declarations
bool kConfigurationValuesDebug = false;

/// Logs a timestamped event (no-op when [kConfigurationValuesDebug] is
/// false).
///
/// Filter output with the component prefix:
///   flutter run 2>&1 | grep '\[CV'
void configurationValuesTrail(String event) {
  if (!kConfigurationValuesDebug) return;
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final ts =
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[CV $ts] $event');
}

import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — Configuration tiles (tom_configuration_ui)
// ============================================================
// true  → event trail + heartbeat + FlutterError intercept enabled
// false → no-op (every trace call returns at once)
//
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// Switchable at run time: a host or a test sets it before the first tile is
// built (a tile that is already built keeps the heartbeat it started with).
// Flip to true whenever investigating lost writes, unexpected rebuilds or
// labels that do not follow the text resources.
// ============================================================
// ignore: prefer_const_declarations
bool kConfigurationUiDebug = false;

/// Logs a timestamped event (no-op when [kConfigurationUiDebug] is false).
///
/// Filter output with the component prefix:
///   flutter run 2>&1 | grep '\[CU'
void configurationUiTrail(String event) {
  if (!kConfigurationUiDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[CU $ts] $event');
}

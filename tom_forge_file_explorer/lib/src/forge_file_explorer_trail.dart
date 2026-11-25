import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — Forge file explorer
// ============================================================
// true  → event trail of the explorer's actions (roots, filter, walk)
// false → no-op
//
// Switchable at run time (a host or a test sets it), so not const.
// KEEP THIS FLAG. Do NOT remove even when not actively debugging.
// ============================================================
bool kForgeFileExplorerDebug = false;

/// Logs a timestamped explorer event (a no-op while
/// [kForgeFileExplorerDebug] is false).
///
/// Filter the output with the prefix: `flutter run 2>&1 | grep '\[FX'`.
void forgeExplorerTrail(String event) {
  if (!kForgeFileExplorerDebug) return;
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final ts =
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FX $ts] $event');
}

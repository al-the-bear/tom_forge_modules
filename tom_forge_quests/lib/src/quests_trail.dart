import 'package:flutter/foundation.dart';

// ============================================================
// DEBUG MODE SWITCH — Forge quest applications
// ============================================================
// true  → event trail of the quest applications (picker, open, activate,
//         lifecycle) to debugPrint
// false → zero-cost no-op (the compiler drops every trace call)
//
// KEEP THIS FLAG. Flip it to true when investigating which quest
// application opened, activated or vetoed a close, and why.
//
// See: tom_ai/forge_modules/_agent_guidelines/debug_mode.md
// ============================================================
const bool kForgeQuestsDebug = false;

/// Logs a timestamped event of the quest applications (no-op when
/// [kForgeQuestsDebug] is false).
///
/// Filter the console with the component prefix:
///   flutter run 2>&1 | grep '\[FQ'
void questsTrailEvent(String event) {
  if (!kForgeQuestsDebug) return;
  final now = DateTime.now();
  final ts =
      '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[FQ $ts] $event');
}

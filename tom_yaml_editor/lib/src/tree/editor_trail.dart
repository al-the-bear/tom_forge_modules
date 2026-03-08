import 'package:flutter/foundation.dart';

/// Lightweight event trail for freeze / hang diagnosis.
///
/// Every meaningful user action, controller operation, and focus change is
/// printed here via [debugPrint].  The output is rate-limited and thread-safe,
/// so calling this on every event is fine.
///
/// Filter the Flutter console with the `[YE]` prefix, e.g.:
///   flutter run 2>&1 | grep '\[YE\]'
void trailEvent(String event) {
  final now = DateTime.now();
  final ts = '${now.hour.toString().padLeft(2, '0')}'
      ':${now.minute.toString().padLeft(2, '0')}'
      ':${now.second.toString().padLeft(2, '0')}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[YE $ts] $event');
}

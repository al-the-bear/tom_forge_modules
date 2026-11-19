import 'package:flutter/animation.dart';

/// Animation constants for shell UI.
class ForgeAnimations {
  /// When true, all durations return [Duration.zero] and curves use
  /// [Curves.linear]. The shell scaffold sets it from the user's
  /// *Reduce motion* preference.
  static bool reduceMotion = false;

  static Duration get panelTransition =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  static Duration get tabTransition =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
  static Duration get dropZoneFade =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 100);
  static Duration get shortcutPopupIn =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);
  static Duration get shortcutPopupOut =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 100);
  static Duration get notificationIn =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  static Duration get notificationOut =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);

  static Curve get panelCurve =>
      reduceMotion ? Curves.linear : Curves.easeOutCubic;
  static Curve get tabCurve => reduceMotion ? Curves.linear : Curves.easeOut;
  static Curve get popupCurve =>
      reduceMotion ? Curves.linear : Curves.easeOutBack;
}

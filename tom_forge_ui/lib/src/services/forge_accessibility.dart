import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Accessibility announcement pipeline for the Forge shell.
///
/// Wraps [SemanticsService.sendAnnouncement] with polite/assertive modes
/// to communicate state changes to screen readers.
class ForgeAccessibility {
  ForgeAccessibility._();

  /// Announce a message politely (queued, non-interrupting).
  ///
  /// Use for routine state changes: tab switched, file opened, panel toggled.
  static void announcePolite(String message,
      {TextDirection textDirection = TextDirection.ltr}) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      message,
      textDirection,
      assertiveness: Assertiveness.polite,
    );
  }

  /// Announce a message assertively (interrupts current speech).
  ///
  /// Use for important events: errors, confirmations, modal opened.
  static void announceAssertive(String message,
      {TextDirection textDirection = TextDirection.ltr}) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      message,
      textDirection,
      assertiveness: Assertiveness.assertive,
    );
  }
}

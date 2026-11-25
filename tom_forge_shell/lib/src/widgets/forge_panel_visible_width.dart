import 'package:flutter/widgets.dart';

/// The width of a side panel's content that is on screen.
///
/// A side panel lays its content out at least as wide as the shell's
/// *Panel content minimum width* and clips what does not fit; content that
/// adapts to any width itself (the configuration tiles) lays out at this
/// width instead, so none of its controls is clipped.
class ForgePanelVisibleWidth extends InheritedWidget {
  const ForgePanelVisibleWidth({
    super.key,
    required this.width,
    required super.child,
  });

  /// The width on screen, in logical pixels.
  final double width;

  /// The nearest visible width, or null outside a side panel.
  static double? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ForgePanelVisibleWidth>()
      ?.width;

  @override
  bool updateShouldNotify(ForgePanelVisibleWidth oldWidget) =>
      width != oldWidget.width;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where a status item sits in the status bar.
enum StatusBarAlignment { left, center, right }

/// Builds a status item's content in place of its icon and text — a chip, a
/// countdown, a coloured indicator. [foreground] is the colour the bar draws
/// its text in.
typedef ForgeStatusItemBuilder =
    Widget Function(BuildContext context, Color foreground);

/// One item of a [ForgeStatusBar], free of any shell state: what it shows
/// ([text], [icon], or [builder]), where ([alignment], [priority]), whether
/// it is shown now ([visible]), and what a tap does.
class ForgeStatusItem {
  const ForgeStatusItem({
    required this.text,
    this.icon,
    this.alignment = StatusBarAlignment.left,
    this.priority = 0,
    this.onTap,
    this.tooltip,
    this.visible,
    this.color,
    this.emphasis = false,
    this.builder,
  });

  /// The text shown, followed as it changes.
  final ValueListenable<String> text;

  /// An icon before the text.
  final IconData? icon;

  final StatusBarAlignment alignment;

  /// Higher first within its alignment.
  final int priority;

  final VoidCallback? onTap;
  final String? tooltip;

  /// Whether the item is shown; the bar rebuilds when it changes. Null:
  /// always shown.
  final ValueListenable<bool>? visible;

  /// The colour of the icon and text; null: the bar's foreground.
  final Color? color;

  /// Draws the text bold.
  final bool emphasis;

  /// Replaces the icon and text with a widget of its own.
  final ForgeStatusItemBuilder? builder;

  /// Whether the item is shown now.
  bool get isVisible => visible?.value ?? true;
}

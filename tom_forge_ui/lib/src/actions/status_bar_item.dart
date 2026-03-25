import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../shell/forge_system_state.dart';

/// Alignment for status bar items.
enum StatusBarAlignment { left, center, right }

/// A single status bar item contributed by a module or the shell.
class StatusBarItem {
  final ValueListenable<String> text;
  final IconData? icon;
  final StatusBarAlignment alignment;
  final int priority;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool Function(ForgeSystemState state) isActive;

  const StatusBarItem({
    required this.text,
    this.icon,
    this.alignment = StatusBarAlignment.left,
    this.priority = 0,
    this.onTap,
    this.tooltip,
    required this.isActive,
  });
}

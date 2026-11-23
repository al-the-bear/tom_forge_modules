import 'package:tom_forge_core/tom_forge_core.dart' show StatusBarAlignment;

import '../kit/forge_kit_state.dart';

/// A status item as data: what it says ([text], [tooltip]), where it sits
/// ([alignment], [priority]), what a tap does ([onTap]) and when it applies
/// ([isActive], asked with the current [ForgeKitState]).
///
/// The kit draws nothing; an application shows the active items as it
/// decides.
class ForgeKitStatusItem {
  const ForgeKitStatusItem({
    required this.text,
    this.tooltip,
    this.alignment = StatusBarAlignment.left,
    this.priority = 0,
    this.onTap,
    this.isActive = _always,
  });

  /// The text shown.
  final String text;

  final String? tooltip;

  final StatusBarAlignment alignment;

  /// Higher first within its alignment.
  final int priority;

  final void Function()? onTap;

  /// Whether the item applies in [ForgeKitState]'s current state; always by
  /// default.
  final bool Function(ForgeKitState state) isActive;

  static bool _always(ForgeKitState state) => true;
}

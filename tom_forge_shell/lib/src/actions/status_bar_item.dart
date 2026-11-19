import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

import '../shell/forge_system_state.dart';

export 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show StatusBarAlignment, ForgeStatusItem, ForgeStatusItemBuilder;

/// A status bar item contributed by a module, an application or the shell:
/// a [ForgeStatusItem] that is shown only while [isActive] holds for the
/// shell's [ForgeSystemState] (the focused panel, the active editor, the
/// diagnostics). [ForgeStatusBarWidget] filters by it and hands the rest to
/// the shared [ForgeStatusBar].
class StatusBarItem extends ForgeStatusItem {
  const StatusBarItem({
    required super.text,
    super.icon,
    super.alignment,
    super.priority,
    super.onTap,
    super.tooltip,
    super.visible,
    super.color,
    super.emphasis,
    super.builder,
    required this.isActive,
  });

  /// Whether the item applies in the shell's current state.
  final bool Function(ForgeSystemState state) isActive;
}

import 'package:flutter/widgets.dart';

import 'forge_shortcut_binding.dart';
import '../shell/forge_system_state.dart';

/// Menu location for action placement.
///
/// Extends the core enum with shell-specific values.
enum ForgeMenuLocation {
  file,
  edit,
  view,
  go,
  run,
  tools,
  help,
  contextMenu,
  commandPalette,
}

/// A command that can appear in menus, toolbars, and the command palette.
class ForgeAction {
  final String id;
  final String label;
  final IconData? icon;
  final ForgeMenuLocation menu;
  final String? group;
  final int priority;
  final Future<Object?> Function(Map<String, Object> parameters) execute;
  final bool Function() isEnabled;
  final bool Function() isVisible;
  final ForgeShortcutBinding? shortcut;
  final Future<void> Function(Object undoInfo)? undo;

  const ForgeAction({
    required this.id,
    required this.label,
    this.icon,
    this.menu = ForgeMenuLocation.commandPalette,
    this.group,
    this.priority = 0,
    required this.execute,
    required this.isEnabled,
    required this.isVisible,
    this.shortcut,
    this.undo,
  });
}

/// A context menu contribution tied to a condition.
class ForgeContextMenuContribution {
  final ForgeAction action;
  final bool Function(ForgeSystemState state) isApplicable;

  const ForgeContextMenuContribution({
    required this.action,
    required this.isApplicable,
  });
}

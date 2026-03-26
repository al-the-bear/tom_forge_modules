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
///
/// This is the unified action type for both shell-level and editor-level
/// actions. Use [ForgeAction.editing] for simple synchronous editing operations.
class ForgeAction {
  /// Unique identifier (e.g., 'file.save', 'edit.cut', 'dart.openReference').
  final String id;

  /// Display label for menus and command palette.
  final String label;

  /// Optional icon for menus and toolbars.
  final IconData? icon;

  /// Menu location for this action.
  final ForgeMenuLocation menu;

  /// Optional group within the menu for organizing related actions.
  final String? group;

  /// Priority for ordering within a group (lower = higher priority).
  final int priority;

  /// Execute the action. Parameters are optional context passed by the caller.
  /// Returns optional undo information for [undo] callback.
  final Future<Object?> Function(Map<String, Object> parameters) execute;

  /// Whether the action is currently enabled.
  final bool Function() isEnabled;

  /// Whether the action is currently visible in menus.
  final bool Function() isVisible;

  /// Default keyboard shortcut (before any rebinding).
  /// The shell may rebind this via [ForgeShortcutManager].
  final ForgeShortcutKey? defaultShortcut;

  /// Whether this action should appear in context menus.
  final bool showInContextMenu;

  /// Legacy shortcut binding (deprecated, use [defaultShortcut]).
  @Deprecated('Use defaultShortcut instead')
  final ForgeShortcutBinding? shortcut;

  /// Optional undo handler. Called with the return value from [execute].
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
    this.defaultShortcut,
    this.showInContextMenu = false,
    @Deprecated('Use defaultShortcut instead') this.shortcut,
    this.undo,
  });

  /// Creates a simple editing action with synchronous execution.
  ///
  /// This factory simplifies creating common text editing operations
  /// like cut, copy, paste, delete line, etc.
  ///
  /// ```dart
  /// ForgeAction.editing(
  ///   id: 'edit.cut',
  ///   label: 'Cut',
  ///   shortcut: ForgeShortcutKey(key: LogicalKeyboardKey.keyX, primaryModifier: true),
  ///   showInContextMenu: true,
  ///   execute: () {
  ///     // cut logic
  ///     return true; // handled
  ///   },
  ///   isEnabled: () => controller.selection.isValid,
  /// )
  /// ```
  factory ForgeAction.editing({
    required String id,
    required String label,
    IconData? icon,
    ForgeShortcutKey? shortcut,
    bool showInContextMenu = false,
    required bool Function() execute,
    required bool Function() isEnabled,
  }) {
    return ForgeAction(
      id: id,
      label: label,
      icon: icon,
      menu: ForgeMenuLocation.edit,
      defaultShortcut: shortcut,
      showInContextMenu: showInContextMenu,
      execute: (_) async {
        execute();
        return null;
      },
      isEnabled: isEnabled,
      isVisible: () => true,
    );
  }
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

import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeText, ForgeTextResolver;

import 'forge_shortcut_key.dart';

/// Whether debug logging is enabled for forge_action operations.
bool kForgeActionDebug = false;

void _log(String message) {
  if (kForgeActionDebug) {
    // ignore: avoid_print
    print('[ForgeAction] $message');
  }
}

/// Menu location for action placement.
///
/// Determines where an action appears in the shell UI.
enum ForgeMenuLocation {
  /// File menu (New, Open, Save, etc.)
  file,

  /// Edit menu (Undo, Redo, Cut, Copy, Paste, etc.)
  edit,

  /// View menu (Toggle panels, zoom, etc.)
  view,

  /// Go menu (Go to file, line, symbol, etc.)
  go,

  /// Run menu (Run, Debug, etc.)
  run,

  /// Tools menu (Settings, extensions, etc.)
  tools,

  /// Help menu (Documentation, about, etc.)
  help,

  /// Context menu (right-click menu)
  contextMenu,

  /// Command palette only (not in menus)
  commandPalette,
}

/// A command that can appear in menus, toolbars, and the command palette.
///
/// This is the unified action type for both shell-level and editor-level
/// actions. Use [ForgeAction.editing] for simple synchronous editing operations.
///
/// ```dart
/// // Full action with async execute and undo:
/// ForgeAction(
///   id: 'file.save',
///   label: 'Save',
///   icon: Icons.save,
///   menu: ForgeMenuLocation.file,
///   defaultShortcut: ForgeShortcutKey(
///     key: LogicalKeyboardKey.keyS,
///     primaryModifier: true,
///   ),
///   execute: (params) async {
///     await fileSystem.save(params['uri'] as Uri);
///     return SaveUndoInfo(uri: uri, content: content);
///   },
///   isEnabled: () => document.isDirty,
///   isVisible: () => true,
///   undo: (undoInfo) async {
///     final info = undoInfo as SaveUndoInfo;
///     await fileSystem.write(info.uri, info.content);
///   },
/// )
/// ```
class ForgeAction {
  /// Unique identifier (e.g., 'file.save', 'edit.cut', 'dart.openReference').
  final String id;

  /// Display label for menus and command palette: [title] resolved with
  /// [textResolver] when the action has a title, else the label it was
  /// given. Read when shown, so a new language shows on the next build.
  String get label {
    final title = this.title;
    if (title == null) return _label;
    return textResolver?.resolve(title) ?? title.resolve();
  }

  final String _label;

  /// The label as a text reference (`ForgeText.id('actions.saveAction.label')`,
  /// relative to the owning module's package), or null when the action
  /// has a literal [label]. Resolved with [textResolver].
  final ForgeText? title;

  /// How [title] is read: the owning module's text scope. The module
  /// passes its `textScope`; the kit binds a module's actions that have a
  /// title but no resolver when it registers them ([withTextResolver]).
  /// Null: [title] is read from the application's text resources by its
  /// key alone.
  final ForgeTextResolver? textResolver;

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
  /// The shell may rebind this via shortcut manager.
  final ForgeShortcutKey? defaultShortcut;

  /// Whether this action should appear in context menus.
  final bool showInContextMenu;

  /// Optional undo handler. Called with the return value from [execute].
  final Future<void> Function(Object undoInfo)? undo;

  const ForgeAction({
    required this.id,
    String label = '',
    this.title,
    this.textResolver,
    this.icon,
    this.menu = ForgeMenuLocation.commandPalette,
    this.group,
    this.priority = 0,
    required this.execute,
    required this.isEnabled,
    required this.isVisible,
    this.defaultShortcut,
    this.showInContextMenu = false,
    this.undo,
  }) : _label = label;

  /// This action with [resolver] as its [textResolver], when it has a
  /// [title] and no resolver yet; else this action itself.
  ForgeAction withTextResolver(ForgeTextResolver resolver) =>
      title == null || textResolver != null
          ? this
          : ForgeAction(
              id: id,
              label: _label,
              title: title,
              textResolver: resolver,
              icon: icon,
              menu: menu,
              group: group,
              priority: priority,
              execute: execute,
              isEnabled: isEnabled,
              isVisible: isVisible,
              defaultShortcut: defaultShortcut,
              showInContextMenu: showInContextMenu,
              undo: undo,
            );

  /// Creates a simple editing action with synchronous execution.
  ///
  /// This factory simplifies creating common text editing operations
  /// like cut, copy, paste, delete line, etc.
  ///
  /// ```dart
  /// ForgeAction.editing(
  ///   id: 'edit.cut',
  ///   label: 'Cut',
  ///   shortcut: ForgeShortcutKey(
  ///     key: LogicalKeyboardKey.keyX,
  ///     primaryModifier: true,
  ///   ),
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
    _log('Creating editing action: $id');
    return ForgeAction(
      id: id,
      label: label,
      icon: icon,
      menu: ForgeMenuLocation.edit,
      defaultShortcut: shortcut,
      showInContextMenu: showInContextMenu,
      execute: (_) async {
        _log('Executing action: $id');
        execute();
        return null;
      },
      isEnabled: isEnabled,
      isVisible: () => true,
    );
  }

  @override
  String toString() => 'ForgeAction($id, menu=$menu, '
      'shortcut=${defaultShortcut?.toDisplayString()})';
}

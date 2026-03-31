import 'package:flutter/services.dart';

import '../forge_bridge/forge_action.dart';
import '../forge_bridge/forge_shortcut_key.dart';

/// Factory and constants for standard editing actions.
///
/// Provides consistent action IDs, shortcuts, and action instances
/// for Cut, Copy, Paste, Undo, Redo, and Select All operations.
///
/// Action IDs follow the pattern `forge.edit.<operation>` for namespacing.
class StandardEditingActions {
  StandardEditingActions._();

  // Action IDs
  static const String cutActionId = 'forge.edit.cut';
  static const String copyActionId = 'forge.edit.copy';
  static const String pasteActionId = 'forge.edit.paste';
  static const String selectAllActionId = 'forge.edit.selectAll';
  static const String undoActionId = 'forge.edit.undo';
  static const String redoActionId = 'forge.edit.redo';

  // Standard keyboard shortcuts (using primary modifier - Cmd on Mac, Ctrl elsewhere)
  static final ForgeShortcutKey cutShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyX,
    usePrimaryModifier: true,
  );

  static final ForgeShortcutKey copyShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyC,
    usePrimaryModifier: true,
  );

  static final ForgeShortcutKey pasteShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyV,
    usePrimaryModifier: true,
  );

  static final ForgeShortcutKey selectAllShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyA,
    usePrimaryModifier: true,
  );

  // Concept §11.3: Cmd+U = Undo (non-conventional mapping).
  static final ForgeShortcutKey undoShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyU,
    usePrimaryModifier: true,
  );

  // Concept §11.3: Cmd+Z = Redo (non-conventional mapping).
  static final ForgeShortcutKey redoShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyZ,
    usePrimaryModifier: true,
  );

  // Alternative redo shortcut (Ctrl+Y on Windows/Linux)
  static final ForgeShortcutKey redoAltShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyY,
    usePrimaryModifier: true,
  );

  /// Creates a Cut action.
  ///
  /// The [onCut] callback performs the actual cut operation.
  /// [isEnabled] controls when the action is available.
  static ForgeAction cut({
    bool Function()? onCut,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: cutActionId,
      label: 'Cut',
      shortcut: cutShortcut,
      execute: onCut ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Copy action.
  static ForgeAction copy({
    bool Function()? onCopy,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: copyActionId,
      label: 'Copy',
      shortcut: copyShortcut,
      execute: onCopy ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Paste action.
  static ForgeAction paste({
    bool Function()? onPaste,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: pasteActionId,
      label: 'Paste',
      shortcut: pasteShortcut,
      execute: onPaste ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Select All action.
  static ForgeAction selectAll({
    bool Function()? onSelectAll,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: selectAllActionId,
      label: 'Select All',
      shortcut: selectAllShortcut,
      execute: onSelectAll ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates an Undo action.
  static ForgeAction undo({
    bool Function()? onUndo,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: undoActionId,
      label: 'Undo',
      shortcut: undoShortcut,
      execute: onUndo ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Redo action.
  static ForgeAction redo({
    bool Function()? onRedo,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: redoActionId,
      label: 'Redo',
      shortcut: redoShortcut,
      execute: onRedo ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Returns all standard editing actions.
  static List<ForgeAction> all({
    bool Function()? onCut,
    bool Function()? onCopy,
    bool Function()? onPaste,
    bool Function()? onSelectAll,
    bool Function()? onUndo,
    bool Function()? onRedo,
  }) {
    return [
      cut(onCut: onCut),
      copy(onCopy: onCopy),
      paste(onPaste: onPaste),
      selectAll(onSelectAll: onSelectAll),
      undo(onUndo: onUndo),
      redo(onRedo: onRedo),
    ];
  }

  /// Returns a map of action IDs to their default shortcuts.
  static Map<String, ForgeShortcutKey> get defaultShortcuts => {
        cutActionId: cutShortcut,
        copyActionId: copyShortcut,
        pasteActionId: pasteShortcut,
        selectAllActionId: selectAllShortcut,
        undoActionId: undoShortcut,
        redoActionId: redoShortcut,
      };
}

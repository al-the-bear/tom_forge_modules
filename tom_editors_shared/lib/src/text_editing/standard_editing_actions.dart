import 'package:flutter/services.dart';

import '../forge_bridge/editor_action_descriptor.dart';
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
  static const String deleteLineActionId = 'forge.edit.deleteLine';
  static const String duplicateLineActionId = 'forge.edit.duplicateLine';
  static const String moveLineUpActionId = 'forge.edit.moveLineUp';
  static const String moveLineDownActionId = 'forge.edit.moveLineDown';
  static const String toggleCommentActionId = 'forge.edit.toggleComment';

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

  // Delete line: Cmd+Y / Ctrl+Y (concept §11.1.3).
  static final ForgeShortcutKey deleteLineShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyY,
    usePrimaryModifier: true,
  );

  // Duplicate line: Cmd+D / Ctrl+D.
  static final ForgeShortcutKey duplicateLineShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyD,
    usePrimaryModifier: true,
  );

  // Move line up: Alt+ArrowUp.
  static final ForgeShortcutKey moveLineUpShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.arrowUp,
    alt: true,
  );

  // Move line down: Alt+ArrowDown.
  static final ForgeShortcutKey moveLineDownShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.arrowDown,
    alt: true,
  );

  // Toggle comment: Cmd+/ / Ctrl+/.
  static final ForgeShortcutKey toggleCommentShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.slash,
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

  /// Creates a Delete Line action.
  static ForgeAction deleteLine({
    bool Function()? onDeleteLine,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: deleteLineActionId,
      label: 'Delete Line',
      shortcut: deleteLineShortcut,
      execute: onDeleteLine ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Duplicate Line action.
  static ForgeAction duplicateLine({
    bool Function()? onDuplicateLine,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: duplicateLineActionId,
      label: 'Duplicate Line',
      shortcut: duplicateLineShortcut,
      execute: onDuplicateLine ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Move Line Up action.
  static ForgeAction moveLineUp({
    bool Function()? onMoveLineUp,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: moveLineUpActionId,
      label: 'Move Line Up',
      shortcut: moveLineUpShortcut,
      execute: onMoveLineUp ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Move Line Down action.
  static ForgeAction moveLineDown({
    bool Function()? onMoveLineDown,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: moveLineDownActionId,
      label: 'Move Line Down',
      shortcut: moveLineDownShortcut,
      execute: onMoveLineDown ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a Toggle Comment action.
  static ForgeAction toggleComment({
    bool Function()? onToggleComment,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: toggleCommentActionId,
      label: 'Toggle Comment',
      shortcut: toggleCommentShortcut,
      execute: onToggleComment ?? () => true,
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
        deleteLineActionId: deleteLineShortcut,
        duplicateLineActionId: duplicateLineShortcut,
        moveLineUpActionId: moveLineUpShortcut,
        moveLineDownActionId: moveLineDownShortcut,
        toggleCommentActionId: toggleCommentShortcut,
      };

  /// Returns action descriptors for all standard editing actions.
  static List<EditorActionDescriptor> get descriptors => [
        EditorActionDescriptor(
          id: cutActionId,
          label: 'Cut',
          category: 'Standard',
          contextRule: ActionContext.hasSelection,
          suggestedShortcut: cutShortcut,
        ),
        EditorActionDescriptor(
          id: copyActionId,
          label: 'Copy',
          category: 'Standard',
          contextRule: ActionContext.hasSelection,
          suggestedShortcut: copyShortcut,
        ),
        EditorActionDescriptor(
          id: pasteActionId,
          label: 'Paste',
          category: 'Standard',
          contextRule: ActionContext.editable,
          suggestedShortcut: pasteShortcut,
        ),
        EditorActionDescriptor(
          id: selectAllActionId,
          label: 'Select All',
          category: 'Standard',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: selectAllShortcut,
        ),
        EditorActionDescriptor(
          id: undoActionId,
          label: 'Undo',
          category: 'Standard',
          contextRule: ActionContext.editorFocused,
          suggestedShortcut: undoShortcut,
        ),
        EditorActionDescriptor(
          id: redoActionId,
          label: 'Redo',
          category: 'Standard',
          contextRule: ActionContext.editorFocused,
          suggestedShortcut: redoShortcut,
        ),
        EditorActionDescriptor(
          id: deleteLineActionId,
          label: 'Delete Line',
          category: 'Standard',
          description: 'Delete the current line',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: deleteLineShortcut,
        ),
        EditorActionDescriptor(
          id: duplicateLineActionId,
          label: 'Duplicate Line',
          category: 'Standard',
          description: 'Duplicate the current line below',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: duplicateLineShortcut,
        ),
        EditorActionDescriptor(
          id: moveLineUpActionId,
          label: 'Move Line Up',
          category: 'Standard',
          description: 'Move the current line up',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: moveLineUpShortcut,
        ),
        EditorActionDescriptor(
          id: moveLineDownActionId,
          label: 'Move Line Down',
          category: 'Standard',
          description: 'Move the current line down',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: moveLineDownShortcut,
        ),
        EditorActionDescriptor(
          id: toggleCommentActionId,
          label: 'Toggle Comment',
          category: 'Standard',
          description: 'Toggle line comment',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: toggleCommentShortcut,
        ),
      ];
}

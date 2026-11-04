import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../forge_bridge/editor_action_descriptor.dart';
import '../forge_bridge/editor_state_snapshot.dart';
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

  /// Saving, for an editor that **owns its model** and writes it itself.
  ///
  /// The host's save writes what `getContent()` returns. An editor whose content
  /// is not one string — a multi-part container, say — returns null there and
  /// lists this id in `supportedActionIds` instead: an explicit save is then
  /// handed to it through `executeAction`, it clears its own dirty state when
  /// the write lands, and the host never marks it clean on its behalf.
  /// Automatic saves leave such an editor alone; when to write is its call.
  static const String saveActionId = 'forge.file.save';

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

  // Undo: Cmd+Z / Ctrl+Z, the platform convention (concept §11.3).
  static final ForgeShortcutKey undoShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyZ,
    usePrimaryModifier: true,
  );

  // Redo: Shift+Cmd+Z / Shift+Ctrl+Z (concept §11.3).
  static final ForgeShortcutKey redoShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyZ,
    usePrimaryModifier: true,
    shift: true,
  );

  // Delete line: Shift+Cmd+K / Shift+Ctrl+K (concept §11.1.3), the key
  // VS Code uses — Ctrl+Y is Redo on Windows and Linux.
  static final ForgeShortcutKey deleteLineShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyK,
    usePrimaryModifier: true,
    shift: true,
  );

  /// Further keys for an action, beside its binding: the platform's second
  /// convention, which every editor and the shell honour and the user does not
  /// rebind. On Windows and Linux Ctrl+Y redoes; on macOS there is none.
  static Map<String, List<ForgeShortcutKey>> get alternateShortcuts =>
      ForgeShortcutKey.primaryIsMeta
      ? const {}
      : {
          redoActionId: [
            ForgeShortcutKey(
              key: LogicalKeyboardKey.keyY,
              usePrimaryModifier: true,
            ),
          ],
        };

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
          icon: Icons.content_cut,
          category: 'Standard',
          contextRule: ActionContext.hasSelection,
          suggestedShortcut: cutShortcut,
        ),
        EditorActionDescriptor(
          id: copyActionId,
          label: 'Copy',
          icon: Icons.copy,
          category: 'Standard',
          contextRule: ActionContext.hasSelection,
          suggestedShortcut: copyShortcut,
        ),
        EditorActionDescriptor(
          id: pasteActionId,
          label: 'Paste',
          icon: Icons.paste,
          category: 'Standard',
          contextRule: ActionContext.editable,
          suggestedShortcut: pasteShortcut,
        ),
        EditorActionDescriptor(
          id: selectAllActionId,
          label: 'Select All',
          icon: Icons.select_all,
          category: 'Standard',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: selectAllShortcut,
        ),
        EditorActionDescriptor(
          id: undoActionId,
          label: 'Undo',
          icon: Icons.undo,
          category: 'Standard',
          contextRule: ActionContext.editorFocused,
          suggestedShortcut: undoShortcut,
        ),
        EditorActionDescriptor(
          id: redoActionId,
          label: 'Redo',
          icon: Icons.redo,
          category: 'Standard',
          contextRule: ActionContext.editorFocused,
          suggestedShortcut: redoShortcut,
        ),
        EditorActionDescriptor(
          id: deleteLineActionId,
          label: 'Delete Line',
          icon: Icons.delete_sweep,
          category: 'Standard',
          description: 'Delete the current line',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: deleteLineShortcut,
        ),
        EditorActionDescriptor(
          id: duplicateLineActionId,
          label: 'Duplicate Line',
          icon: Icons.content_copy,
          category: 'Standard',
          description: 'Duplicate the current line below',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: duplicateLineShortcut,
        ),
        EditorActionDescriptor(
          id: moveLineUpActionId,
          label: 'Move Line Up',
          icon: Icons.arrow_upward,
          category: 'Standard',
          description: 'Move the current line up',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: moveLineUpShortcut,
        ),
        EditorActionDescriptor(
          id: moveLineDownActionId,
          label: 'Move Line Down',
          icon: Icons.arrow_downward,
          category: 'Standard',
          description: 'Move the current line down',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: moveLineDownShortcut,
        ),
        EditorActionDescriptor(
          id: toggleCommentActionId,
          label: 'Toggle Comment',
          icon: Icons.code_off,
          category: 'Standard',
          description: 'Toggle line comment',
          contextRule: ActionContext.textEditorFocused,
          suggestedShortcut: toggleCommentShortcut,
        ),
      ];

  /// Set of all standard editing action IDs.
  static const Set<String> standardActionIds = {
    cutActionId,
    copyActionId,
    pasteActionId,
    selectAllActionId,
    undoActionId,
    redoActionId,
    deleteLineActionId,
    duplicateLineActionId,
    moveLineUpActionId,
    moveLineDownActionId,
    toggleCommentActionId,
  };

  /// Returns the enablement rule for the given [actionId] as a pure
  /// function of [EditorStateSnapshot].
  ///
  /// This replaces all ad-hoc isEnabled closures. The rule is evaluated
  /// by the shell against the active editor's current state snapshot.
  ///
  /// Returns a function that always returns false for unknown action IDs.
  static bool Function(EditorStateSnapshot) enablementRule(String actionId) {
    return switch (actionId) {
      cutActionId => (s) => s.isEditable && s.hasSelection,
      copyActionId => (s) => s.hasSelection,
      pasteActionId => (s) => s.isEditable,
      selectAllActionId => (s) => s.hasContent && s.isTextMode,
      undoActionId => (s) => s.canUndo,
      redoActionId => (s) => s.canRedo,
      deleteLineActionId => (s) => s.isEditable && s.isTextMode,
      duplicateLineActionId => (s) => s.isEditable && s.isTextMode,
      moveLineUpActionId => (s) => s.isEditable && s.isTextMode,
      moveLineDownActionId => (s) => s.isEditable && s.isTextMode,
      toggleCommentActionId => (s) => s.isEditable && s.isTextMode,
      saveActionId => (s) => s.hasContent,
      _ => (_) => false,
    };
  }
}

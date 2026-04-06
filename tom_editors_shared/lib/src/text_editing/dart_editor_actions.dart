import 'package:flutter/services.dart';

import '../forge_bridge/forge_action.dart';
import '../forge_bridge/forge_shortcut_key.dart';

/// Constants and factory methods for Dart editor-specific actions.
///
/// Provides consistent action IDs, keyboard shortcuts, and [ForgeAction]
/// instances for operations that are specific to a Dart/code editor
/// (as opposed to the standard editing actions like cut/copy/paste).
///
/// Action IDs follow the pattern `dart.<operation>` for namespacing.
class DartEditorActions {
  DartEditorActions._();

  // ── Action IDs ──────────────────────────────────────────────────────────

  /// Trigger code completion at the current cursor position.
  static const String triggerCompletionActionId = 'dart.triggerCompletion';

  /// Open the API reference dialog.
  static const String openReferenceActionId = 'dart.openReference';

  /// Toggle line comment (prepend/remove `//`).
  static const String toggleCommentActionId = 'dart.toggleComment';

  /// Delete the current line.
  static const String deleteLineActionId = 'dart.deleteLine';

  /// Duplicate the current line below.
  static const String duplicateLineActionId = 'dart.duplicateLine';

  /// Move the current line up.
  static const String moveLineUpActionId = 'dart.moveLineUp';

  /// Move the current line down.
  static const String moveLineDownActionId = 'dart.moveLineDown';

  // ── Keyboard shortcuts ─────────────────────────────────────────────────

  /// Primary shortcut for trigger completion: Ctrl+Space.
  static final ForgeShortcutKey triggerCompletionShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.space,
    usePrimaryModifier: true,
  );

  /// Alternative: Alt+Space (common on Linux/Windows).
  static final ForgeShortcutKey triggerCompletionAltShortcut1 = ForgeShortcutKey(
    key: LogicalKeyboardKey.space,
    alt: true,
  );

  /// Alternative: Ctrl+I (IntelliJ-style).
  static final ForgeShortcutKey triggerCompletionAltShortcut2 = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyI,
    usePrimaryModifier: true,
  );

  /// All alternative shortcuts for trigger completion.
  static final List<ForgeShortcutKey> triggerCompletionAltShortcuts = [
    triggerCompletionAltShortcut1,
    triggerCompletionAltShortcut2,
  ];

  /// Toggle comment: Cmd+/ (macOS) / Ctrl+/ (Windows/Linux).
  static final ForgeShortcutKey toggleCommentShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.slash,
    usePrimaryModifier: true,
  );

  /// Delete line: Cmd+Y / Ctrl+Y (concept §11.3 standard shortcut).
  static final ForgeShortcutKey deleteLineShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyY,
    usePrimaryModifier: true,
  );

  /// Duplicate line: Cmd+D / Ctrl+D.
  static final ForgeShortcutKey duplicateLineShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyD,
    usePrimaryModifier: true,
  );

  /// Move line up: Alt+ArrowUp.
  static final ForgeShortcutKey moveLineUpShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.arrowUp,
    alt: true,
  );

  /// Move line down: Alt+ArrowDown.
  static final ForgeShortcutKey moveLineDownShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.arrowDown,
    alt: true,
  );

  // ── Factory methods ────────────────────────────────────────────────────

  /// Creates a trigger completion action.
  ///
  /// [onTrigger] is called when completion should be shown.
  /// [isEnabled] controls when auto-completion is available.
  static ForgeAction triggerCompletion({
    bool Function()? onTrigger,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: triggerCompletionActionId,
      label: 'Trigger Completion',
      shortcut: triggerCompletionShortcut,
      execute: onTrigger ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates an open reference action.
  static ForgeAction openReference({
    bool Function()? onOpen,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: openReferenceActionId,
      label: 'Open Reference',
      execute: onOpen ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a toggle comment action.
  static ForgeAction toggleComment({
    bool Function()? onToggle,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: toggleCommentActionId,
      label: 'Toggle Comment',
      shortcut: toggleCommentShortcut,
      execute: onToggle ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a delete line action.
  static ForgeAction deleteLine({
    bool Function()? onDelete,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: deleteLineActionId,
      label: 'Delete Line',
      shortcut: deleteLineShortcut,
      execute: onDelete ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a duplicate line action.
  static ForgeAction duplicateLine({
    bool Function()? onDuplicate,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: duplicateLineActionId,
      label: 'Duplicate Line',
      shortcut: duplicateLineShortcut,
      execute: onDuplicate ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a move line up action.
  static ForgeAction moveLineUp({
    bool Function()? onMove,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: moveLineUpActionId,
      label: 'Move Line Up',
      shortcut: moveLineUpShortcut,
      execute: onMove ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a move line down action.
  static ForgeAction moveLineDown({
    bool Function()? onMove,
    bool Function()? isEnabled,
  }) {
    return ForgeAction.editing(
      id: moveLineDownActionId,
      label: 'Move Line Down',
      shortcut: moveLineDownShortcut,
      execute: onMove ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Returns a map of all Dart-specific action IDs to their default shortcuts.
  static Map<String, ForgeShortcutKey> get defaultShortcuts => {
        triggerCompletionActionId: triggerCompletionShortcut,
        toggleCommentActionId: toggleCommentShortcut,
        deleteLineActionId: deleteLineShortcut,
        duplicateLineActionId: duplicateLineShortcut,
        moveLineUpActionId: moveLineUpShortcut,
        moveLineDownActionId: moveLineDownShortcut,
      };

  /// Returns a map of alternative shortcuts (action ID to list of alternatives).
  static Map<String, List<ForgeShortcutKey>> get alternativeShortcuts => {
        triggerCompletionActionId: triggerCompletionAltShortcuts,
      };
}

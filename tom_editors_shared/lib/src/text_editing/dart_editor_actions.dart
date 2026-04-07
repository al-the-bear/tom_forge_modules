import 'package:flutter/services.dart';

import '../forge_bridge/editor_action_descriptor.dart';
import '../forge_bridge/forge_action.dart';
import '../forge_bridge/forge_shortcut_key.dart';

/// Constants and factory methods for Dart editor-specific actions.
///
/// Provides consistent action IDs, keyboard shortcuts, and [ForgeAction]
/// instances for operations that are specific to a Dart/code editor
/// (as opposed to the standard editing actions like cut/copy/paste).
///
/// Action IDs follow the pattern `dart.<operation>` for namespacing.
///
/// Line-editing actions (delete line, duplicate line, move line, toggle comment)
/// are defined in [StandardEditingActions] and shared across all editors.
class DartEditorActions {
  DartEditorActions._();

  // ── Action IDs ──────────────────────────────────────────────────────────

  /// Trigger code completion at the current cursor position.
  static const String triggerCompletionActionId = 'dart.triggerCompletion';

  /// Open the API reference dialog.
  static const String openReferenceActionId = 'dart.openReference';

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

  /// Returns a map of all Dart-specific action IDs to their default shortcuts.
  static Map<String, ForgeShortcutKey> get defaultShortcuts => {
        triggerCompletionActionId: triggerCompletionShortcut,
      };

  /// Returns a map of alternative shortcuts (action ID to list of alternatives).
  static Map<String, List<ForgeShortcutKey>> get alternativeShortcuts => {
        triggerCompletionActionId: triggerCompletionAltShortcuts,
      };

  /// Returns action descriptors for all Dart editor-specific actions.
  static List<EditorActionDescriptor> get descriptors => [
        EditorActionDescriptor(
          id: triggerCompletionActionId,
          label: 'Trigger Completion',
          category: 'Dart Editor',
          description: 'Show autocomplete suggestions at cursor position',
          contextRule: ActionContext.editorFocused,
          suggestedShortcut: triggerCompletionShortcut,
          suggestedAlternatives: triggerCompletionAltShortcuts,
        ),
        EditorActionDescriptor(
          id: openReferenceActionId,
          label: 'Open Reference',
          category: 'Dart Editor',
          description: 'Open the API reference dialog',
          contextRule: ActionContext.editorFocused,
        ),
      ];
}

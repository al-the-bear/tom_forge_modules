import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../forge_bridge/editor_action_descriptor.dart';
import '../forge_bridge/forge_action.dart';
import '../forge_bridge/forge_shortcut_key.dart';

/// Constants and factory methods for YAML editor-specific actions.
///
/// Provides consistent action IDs, keyboard shortcuts, and [ForgeAction]
/// instances for operations specific to a tree-based YAML editor
/// (as opposed to text-based editing actions like cut/copy/paste).
///
/// Action IDs follow the pattern `yaml.<operation>` for namespacing.
///
/// **Key difference from text editor actions:** These actions operate on the
/// tree structure (nodes, keys, values) rather than on text selections.
/// Tree navigation (arrow keys, Enter, Space, Escape, Tab) remains in
/// the `KeyboardListener`, not as ForgeActions.
class YamlEditorActions {
  YamlEditorActions._();

  // ── Action IDs ──────────────────────────────────────────────────────────

  /// Add a new key to the selected node or its parent map.
  static const String addKeyActionId = 'yaml.addKey';

  /// Remove the selected key from the tree.
  static const String removeKeyActionId = 'yaml.removeKey';

  /// Toggle between tree mode and raw text mode.
  static const String toggleTextModeActionId = 'yaml.toggleTextMode';

  /// Save the document.
  static const String saveActionId = 'yaml.save';

  /// Toggle the search panel.
  static const String searchActionId = 'yaml.search';

  // ── Keyboard shortcuts ─────────────────────────────────────────────────

  /// Add key: Cmd+N / Ctrl+N.
  static final ForgeShortcutKey addKeyShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyN,
    usePrimaryModifier: true,
  );

  /// Remove key: Cmd+Delete / Ctrl+Delete.
  static final ForgeShortcutKey removeKeyShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.delete,
    usePrimaryModifier: true,
  );

  /// Toggle text mode: Cmd+T / Ctrl+T.
  static final ForgeShortcutKey toggleTextModeShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyT,
    usePrimaryModifier: true,
  );

  /// Save: Cmd+S / Ctrl+S.
  static final ForgeShortcutKey saveShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyS,
    usePrimaryModifier: true,
  );

  /// Search: Cmd+F / Ctrl+F.
  static final ForgeShortcutKey searchShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyF,
    usePrimaryModifier: true,
  );

  // ── Factory methods ────────────────────────────────────────────────────

  /// Creates an add key action.
  static ForgeAction addKey({
    bool Function()? onExecute,
    bool Function()? isEnabled,
    bool showInContextMenu = true,
  }) {
    return ForgeAction.editing(
      id: addKeyActionId,
      label: 'Add Key',
      shortcut: addKeyShortcut,
      showInContextMenu: showInContextMenu,
      execute: onExecute ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a remove key action.
  static ForgeAction removeKey({
    bool Function()? onExecute,
    bool Function()? isEnabled,
    bool showInContextMenu = true,
  }) {
    return ForgeAction.editing(
      id: removeKeyActionId,
      label: 'Remove Key',
      shortcut: removeKeyShortcut,
      showInContextMenu: showInContextMenu,
      execute: onExecute ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a toggle text mode action.
  static ForgeAction toggleTextMode({
    bool Function()? onExecute,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: toggleTextModeActionId,
      label: 'Toggle Text Mode',
      shortcut: toggleTextModeShortcut,
      showInContextMenu: showInContextMenu,
      execute: onExecute ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a save action.
  static ForgeAction save({
    bool Function()? onSave,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: saveActionId,
      label: 'Save',
      shortcut: saveShortcut,
      showInContextMenu: showInContextMenu,
      execute: onSave ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a search action.
  static ForgeAction search({
    bool Function()? onSearch,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: searchActionId,
      label: 'Find',
      shortcut: searchShortcut,
      showInContextMenu: showInContextMenu,
      execute: onSearch ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  // ── Shortcut map ───────────────────────────────────────────────────────

  /// Returns a map of primary shortcuts (action ID to shortcut key).
  static Map<String, ForgeShortcutKey> get primaryShortcuts => {
        addKeyActionId: addKeyShortcut,
        removeKeyActionId: removeKeyShortcut,
        toggleTextModeActionId: toggleTextModeShortcut,
        saveActionId: saveShortcut,
        searchActionId: searchShortcut,
      };

  /// Returns an empty map — no alternative shortcuts are defined for
  /// YAML actions at this time.
  static Map<String, List<ForgeShortcutKey>> get alternativeShortcuts =>
      const {};

  // ── Context menu helpers ───────────────────────────────────────────────

  /// Returns the list of default context menu actions.
  ///
  /// These are actions where `showInContextMenu` defaults to `true`.
  static List<ForgeAction> contextMenuActions() => [
        addKey(),
        removeKey(),
      ];

  /// Returns action descriptors for implemented YAML editor-specific actions.
  ///
  /// Only `toggleTextMode` is currently connected to the action system.
  /// `addKey` and `removeKey` work via context menu / toolbar only.
  /// Save and Find are handled by the shell-level `forge.saveAll` and
  /// `forge.focusSearch` actions.
  static List<EditorActionDescriptor> get descriptors => [
        EditorActionDescriptor(
          id: toggleTextModeActionId,
          label: 'Toggle Text Mode',
          icon: Icons.text_fields,
          category: 'YAML Editor',
          description: 'Toggle between tree mode and raw text mode',
          contextRule: ActionContext.editorFocused,
          suggestedShortcut: toggleTextModeShortcut,
        ),
      ];
}

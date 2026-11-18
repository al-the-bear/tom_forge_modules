import 'package:flutter/services.dart';

import '../forge_bridge/editor_action_descriptor.dart';
import '../forge_bridge/forge_action.dart';
import '../forge_bridge/forge_shortcut_key.dart';

/// Constants and factory methods for markdown editor-specific actions.
///
/// Provides consistent action IDs, keyboard shortcuts, and [ForgeAction]
/// instances for operations specific to a markdown editor
/// (as opposed to the standard editing actions like cut/copy/paste).
///
/// Action IDs follow the pattern `md.<operation>` for namespacing.
class MdEditorActions {
  MdEditorActions._();

  // ── Action IDs ──────────────────────────────────────────────────────────

  /// Toggle bold formatting around the selection.
  static const String toggleBoldActionId = 'md.toggleBold';

  /// Toggle italic formatting around the selection.
  static const String toggleItalicActionId = 'md.toggleItalic';

  /// Toggle inline code formatting around the selection.
  static const String toggleCodeActionId = 'md.toggleCode';

  /// Insert a markdown link at the cursor.
  static const String insertLinkActionId = 'md.insertLink';

  /// Insert a markdown table at the cursor.
  static const String insertTableActionId = 'md.insertTable';

  /// Insert a heading marker at the cursor.
  static const String insertHeadingActionId = 'md.insertHeading';

  /// Toggle list formatting for the current line.
  static const String toggleListActionId = 'md.toggleList';

  /// Save the document.
  static const String saveActionId = 'md.save';

  /// Toggle the search panel.
  static const String searchActionId = 'md.search';

  // ── Keyboard shortcuts ─────────────────────────────────────────────────

  /// Bold: Cmd+B / Ctrl+B.
  static final ForgeShortcutKey toggleBoldShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyB,
    primaryModifier: true,
  );

  /// Italic: Cmd+I / Ctrl+I.
  static final ForgeShortcutKey toggleItalicShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyI,
    primaryModifier: true,
  );

  /// Inline code: Cmd+E / Ctrl+E.
  static final ForgeShortcutKey toggleCodeShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyE,
    primaryModifier: true,
  );

  /// Insert link: Cmd+K / Ctrl+K.
  static final ForgeShortcutKey insertLinkShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyK,
    primaryModifier: true,
  );

  /// Insert table: Alt+T.
  static final ForgeShortcutKey insertTableShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyT,
    alt: true,
  );

  /// Insert heading: Alt+H.
  static final ForgeShortcutKey insertHeadingShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyH,
    alt: true,
  );

  /// Toggle list: Alt+L.
  static final ForgeShortcutKey toggleListShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyL,
    alt: true,
  );

  /// Save: Cmd+S / Ctrl+S.
  static final ForgeShortcutKey saveShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyS,
    primaryModifier: true,
  );

  /// Search: Cmd+F / Ctrl+F.
  static final ForgeShortcutKey searchShortcut = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyF,
    primaryModifier: true,
  );

  // ── Factory methods ────────────────────────────────────────────────────

  /// Creates a toggle bold action.
  static ForgeAction toggleBold({
    bool Function()? onToggle,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: toggleBoldActionId,
      label: 'Bold',
      shortcut: toggleBoldShortcut,
      showInContextMenu: showInContextMenu,
      execute: onToggle ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a toggle italic action.
  static ForgeAction toggleItalic({
    bool Function()? onToggle,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: toggleItalicActionId,
      label: 'Italic',
      shortcut: toggleItalicShortcut,
      showInContextMenu: showInContextMenu,
      execute: onToggle ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a toggle code action.
  static ForgeAction toggleCode({
    bool Function()? onToggle,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: toggleCodeActionId,
      label: 'Inline Code',
      shortcut: toggleCodeShortcut,
      showInContextMenu: showInContextMenu,
      execute: onToggle ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates an insert link action.
  static ForgeAction insertLink({
    bool Function()? onInsert,
    bool Function()? isEnabled,
    bool showInContextMenu = true,
  }) {
    return ForgeAction.editing(
      id: insertLinkActionId,
      label: 'Insert Link',
      shortcut: insertLinkShortcut,
      showInContextMenu: showInContextMenu,
      execute: onInsert ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates an insert table action.
  static ForgeAction insertTable({
    bool Function()? onInsert,
    bool Function()? isEnabled,
    bool showInContextMenu = true,
  }) {
    return ForgeAction.editing(
      id: insertTableActionId,
      label: 'Insert Table',
      shortcut: insertTableShortcut,
      showInContextMenu: showInContextMenu,
      execute: onInsert ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates an insert heading action.
  static ForgeAction insertHeading({
    bool Function()? onInsert,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: insertHeadingActionId,
      label: 'Insert Heading',
      shortcut: insertHeadingShortcut,
      showInContextMenu: showInContextMenu,
      execute: onInsert ?? () => true,
      isEnabled: isEnabled ?? () => true,
    );
  }

  /// Creates a toggle list action.
  static ForgeAction toggleList({
    bool Function()? onToggle,
    bool Function()? isEnabled,
    bool showInContextMenu = false,
  }) {
    return ForgeAction.editing(
      id: toggleListActionId,
      label: 'Toggle List',
      shortcut: toggleListShortcut,
      showInContextMenu: showInContextMenu,
      execute: onToggle ?? () => true,
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
        toggleBoldActionId: toggleBoldShortcut,
        toggleItalicActionId: toggleItalicShortcut,
        toggleCodeActionId: toggleCodeShortcut,
        insertLinkActionId: insertLinkShortcut,
        insertTableActionId: insertTableShortcut,
        insertHeadingActionId: insertHeadingShortcut,
        toggleListActionId: toggleListShortcut,
        saveActionId: saveShortcut,
        searchActionId: searchShortcut,
      };

  /// Returns an empty map — no alternative shortcuts are defined for
  /// markdown actions at this time.
  static Map<String, List<ForgeShortcutKey>> get alternativeShortcuts =>
      const {};

  // ── Context menu helpers ───────────────────────────────────────────────

  /// Returns the list of default context menu actions.
  ///
  /// These are actions where `showInContextMenu` defaults to `true`.
  /// Call this to get the default set; individual actions can be customized
  /// by calling the factory methods with `showInContextMenu` overrides.
  static List<ForgeAction> contextMenuActions() => [
        insertTable(),
        insertLink(),
      ];

  /// Returns action descriptors for implemented Markdown editor-specific
  /// actions.
  ///
  /// Formatting actions (bold, italic, code, link, table, heading, list)
  /// are not yet connected to the action system — they only work via
  /// toolbar buttons. Save and Find are handled by the shell-level
  /// `forge.saveAll` and `forge.focusSearch` actions.
  static List<EditorActionDescriptor> get descriptors => const [];
}

import 'package:flutter/services.dart';

import 'forge_action.dart';

/// An entry in a shortcut menu — a follow-up key bound to an action.
class ForgeShortcutMenuEntry {
  /// The bare key the user presses after the menu opens.
  final LogicalKeyboardKey key;

  /// The action to execute when this entry is selected.
  final ForgeAction action;

  const ForgeShortcutMenuEntry({
    required this.key,
    required this.action,
  });

  /// Single-character display label for the key badge (e.g. "R", "N").
  String get keyLabel => key.keyLabel;
}

/// A custom shortcut menu activated by `Shift+Cmd/Ctrl+<trigger>`.
///
/// Each module can contribute one or more shortcut menus. When the user
/// presses the trigger combination, a popup appears showing the
/// available follow-up actions. The user can press a bare key, click an
/// entry, or use arrow keys + Enter.
class ForgeShortcutMenu {
  /// The trigger key (without modifiers). The menu opens on
  /// `Shift+Cmd+<triggerKey>` (macOS) or `Shift+Ctrl+<triggerKey>`.
  final LogicalKeyboardKey triggerKey;

  /// Display label for the menu (shown in the popup header).
  final String label;

  /// The follow-up entries.
  final List<ForgeShortcutMenuEntry> entries;

  const ForgeShortcutMenu({
    required this.triggerKey,
    required this.label,
    required this.entries,
  });

  /// Single-character label for the trigger key.
  String get triggerKeyLabel => triggerKey.keyLabel;
}

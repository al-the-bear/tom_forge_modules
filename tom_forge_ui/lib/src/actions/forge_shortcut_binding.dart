import 'package:flutter/services.dart';

import 'forge_action.dart';

/// A keyboard shortcut key combination.
class ForgeShortcutKey {
  final LogicalKeyboardKey key;
  final bool primaryModifier;
  final bool shift;
  final bool alt;

  const ForgeShortcutKey({
    required this.key,
    this.primaryModifier = false,
    this.shift = false,
    this.alt = false,
  });

  @override
  bool operator ==(Object other) =>
      other is ForgeShortcutKey &&
      key == other.key &&
      primaryModifier == other.primaryModifier &&
      shift == other.shift &&
      alt == other.alt;

  @override
  int get hashCode => Object.hash(key, primaryModifier, shift, alt);
}

/// A binding between an action and a keyboard shortcut.
class ForgeShortcutBinding {
  final ForgeAction action;
  final ForgeShortcutKey key;

  /// Optional context constraint (e.g. 'editorFocus').
  final String? context;

  const ForgeShortcutBinding({
    required this.action,
    required this.key,
    this.context,
  });
}

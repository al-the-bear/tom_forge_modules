import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../forge_fixed_listenable.dart';

/// One button of a [ForgeActionBar]: an action the caller knows how to run,
/// with what the bar shows for it and whether it can run now.
class ForgeActionItem {
  const ForgeActionItem({
    required this.id,
    required this.icon,
    required this.label,
    this.shortcut,
    this.enabled = const ForgeFixedListenable<bool>(true),
    this.onInvoke,
  });

  /// The action's id; the button's key is `ValueKey('forge.actionBar.<id>')`.
  final String id;

  final IconData icon;

  /// The tooltip, and the overflow menu's entry.
  final String label;

  /// The shortcut as the user reads it (`⌘C`), shown under [label] in the
  /// tooltip and beside it in the overflow menu.
  final String? shortcut;

  /// Whether the action can run in the current context; the button follows
  /// it.
  final ValueListenable<bool> enabled;

  /// Runs the action; null: the button is disabled.
  final VoidCallback? onInvoke;

  /// Whether the button can be pressed now.
  bool get isEnabled => onInvoke != null && enabled.value;

  /// The tooltip text.
  String get tooltip => shortcut != null ? '$label\n$shortcut' : label;
}

/// A group of [ForgeActionItem]s, set apart from its neighbours by a
/// divider.
class ForgeActionGroup {
  const ForgeActionGroup({required this.id, required this.items});

  final String id;
  final List<ForgeActionItem> items;
}

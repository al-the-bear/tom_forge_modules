import 'package:flutter/widgets.dart' show IconData;
import 'package:tom_editors_shared/text_types.dart' show StandardEditingActions;

import '../actions/forge_action.dart';
import '../kit/forge_kit_api.dart';

/// One action as an element shows it now: its label, icon and key, and
/// whether it can run and is shown — read from the kit's action registry and
/// shortcut table ([ForgeActionState.of]). Pure data; running it is
/// `api.executeAction(id)`.
class ForgeActionState {
  const ForgeActionState({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.group,
    this.enabled = true,
    this.visible = true,
  });

  /// The action's id, what `api.executeAction` runs.
  final String id;

  final String label;

  /// The action's icon; null when it has none (an element draws its own
  /// placeholder).
  final IconData? icon;

  /// The bound key as the user reads it (`⌘C`, `Ctrl+K Ctrl+C`), or null.
  final String? shortcut;

  /// The action's group within its menu, or null.
  final String? group;

  /// Whether the action can run now ([forgeActionEnabled]).
  final bool enabled;

  /// Whether the action is shown now (`ForgeAction.isVisible`).
  final bool visible;

  /// The state of the action [actionId] in [api] now; null when no such
  /// action is registered.
  static ForgeActionState? of(ForgeKitApi api, String actionId) {
    final action = api.actionRegistry.getAction(actionId);
    return action == null ? null : ofAction(api, action);
  }

  /// The state of [action] in [api] now.
  static ForgeActionState ofAction(ForgeKitApi api, ForgeAction action) =>
      ForgeActionState(
        id: action.id,
        label: action.label,
        icon: action.icon,
        shortcut: api.shortcuts.getBinding(action.id)?.displayString,
        group: action.group,
        enabled: forgeActionEnabled(api, action),
        visible: action.isVisible(),
      );

  @override
  bool operator ==(Object other) =>
      other is ForgeActionState &&
      other.id == id &&
      other.label == label &&
      other.icon == icon &&
      other.shortcut == shortcut &&
      other.group == group &&
      other.enabled == enabled &&
      other.visible == visible;

  @override
  int get hashCode =>
      Object.hash(id, label, icon, shortcut, group, enabled, visible);

  @override
  String toString() =>
      'ForgeActionState($id, enabled: $enabled, visible: $visible)';
}

/// Whether [action] can run now in [api]: a standard editing action
/// (`StandardEditingActions`: cut, copy, paste, undo, redo, ...) follows the
/// active editor's state snapshot through its enablement rule; any other
/// action — and a standard one while no editor is active — its own
/// `isEnabled`.
bool forgeActionEnabled(ForgeKitApi api, ForgeAction action) {
  if (StandardEditingActions.standardActionIds.contains(action.id)) {
    final snapshot = api.state.activeEditor?.stateSnapshot;
    if (snapshot != null) {
      return StandardEditingActions.enablementRule(action.id)(snapshot);
    }
  }
  return action.isEnabled();
}

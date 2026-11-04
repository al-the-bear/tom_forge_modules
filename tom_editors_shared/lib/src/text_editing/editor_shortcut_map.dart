import 'package:flutter/widgets.dart';

import '../forge_bridge/forge_shortcut_key.dart';
import 'forge_editor_integration.dart';
import 'standard_editing_actions.dart';

/// An editor's local key map: each supported action's key from
/// [ForgeEditorIntegration.getShortcutForAction] — the shell's binding table
/// when the editor is hosted — plus the platform's alternate keys
/// ([StandardEditingActions.alternateShortcuts]) for the supported actions,
/// and the editor's own [alternates], each mapped to the action id.
///
/// Every editor builds its map here and nowhere else, so one key has one
/// meaning in every editor and in the shell, and rebuilds it when
/// [ForgeEditorIntegration.shortcutBindings] notifies — the user rebound a
/// key. A key bound to two actions keeps the first supported action's.
Map<ShortcutActivator, String> buildEditorShortcutMap(
  ForgeEditorIntegration integration, {
  Map<String, List<ForgeShortcutKey>> alternates = const {},
}) {
  // Keyed by ForgeShortcutKey, which has value equality (an activator has
  // none), so a key is taken once.
  final map = <ForgeShortcutKey, String>{};
  final supported = [for (final action in integration.supportedActions) action.id];
  for (final id in supported) {
    final key = integration.getShortcutForAction(id);
    if (key != null) map.putIfAbsent(key, () => id);
  }
  for (final entry in StandardEditingActions.alternateShortcuts.entries) {
    if (!supported.contains(entry.key)) continue;
    for (final key in entry.value) {
      map.putIfAbsent(key, () => entry.key);
    }
  }
  // The editor's own alternates are for actions it handles itself, whether
  // or not the integration lists them.
  for (final entry in alternates.entries) {
    for (final key in entry.value) {
      map.putIfAbsent(key, () => entry.key);
    }
  }
  return {for (final entry in map.entries) entry.key.toActivator(): entry.value};
}

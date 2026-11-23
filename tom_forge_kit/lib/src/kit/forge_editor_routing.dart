import 'package:tom_editors_shared/text_types.dart'
    show ForgeShortcutKey, StandardEditingActions;

import '../actions/forge_action.dart';
import '../components/forge_editor.dart';
import '../services/forge_shortcut_manager.dart';
import 'forge_kit_api.dart';

/// The id of Find: the action that opens the search of the active editor
/// (the panel shell's find bar, an editor surface's own find field).
const String forgeFindActionId = 'editor.find';

/// Registers the standard editing actions (cut, copy, paste, select all,
/// undo, redo and the line actions of [StandardEditingActions]) in [api]'s
/// action registry and binds their default keys, so the binding table holds
/// them before any editor opens: one table, each action routed by
/// [ForgeKitApi.executeAction] to the active editor.
///
/// An action already registered and a key already bound are left as they
/// are, so calling it again — from another surface, after a rebind — changes
/// nothing.
void installForgeStandardEditingActions(ForgeKitApi api) {
  final keys = StandardEditingActions.defaultShortcuts;
  for (final descriptor in StandardEditingActions.descriptors) {
    final id = descriptor.id;
    final action = ForgeAction(
      id: id,
      label: descriptor.label,
      icon: descriptor.icon,
      execute: (_) async {
        api.executeAction(id);
        return null;
      },
      isEnabled: () => api.isActionEnabled(id),
      isVisible: () => true,
      defaultShortcut: keys[id],
    );
    if (api.actionRegistry.getAction(id) == null) {
      api.actionRegistry.registerAction(action);
    }
    final shortcut = action.defaultShortcut;
    if (shortcut != null && api.shortcuts.getBinding(id) == null) {
      api.shortcuts.rebind(action, shortcut);
    }
  }
}

/// The action a pressed [key] stands for: the action whose direct (not
/// chord) binding in [shortcuts] is [key], else the platform's alternate key
/// for a standard editing action
/// ([StandardEditingActions.alternateShortcuts]: Ctrl+Y redoes on Windows and
/// Linux); null when the key is bound to nothing.
String? forgeActionIdForKey(
  ForgeShortcutManager shortcuts,
  ForgeShortcutKey key,
) {
  for (final binding in shortcuts.allBindings) {
    if (!binding.isChord && binding.key == key) return binding.action.id;
  }
  for (final entry in StandardEditingActions.alternateShortcuts.entries) {
    for (final alternate in entry.value) {
      if (alternate == key) return entry.key;
    }
  }
  return null;
}

/// A [ForgeKitApi.state] a widget showing an editor can report to: the
/// editor is shown ([addOpenEditor]), is the one the user works in
/// ([setActiveEditor]), is gone ([removeOpenEditor]).
///
/// `DefaultKitState` is one; a host whose state learns about its editors in
/// another way need not be.
abstract interface class ForgeEditorStateSink {
  void addOpenEditor(ForgeEditor editor);
  void removeOpenEditor(ForgeEditor editor);
  void setActiveEditor(ForgeEditor? editor);
}

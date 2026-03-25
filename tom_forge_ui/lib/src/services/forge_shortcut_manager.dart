import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';

/// Global shortcut management and rebinding.
abstract class ForgeShortcutManager {
  List<ForgeShortcutBinding> get allBindings;
  void rebind(ForgeAction action, ForgeShortcutKey key);
  void resetToDefault(ForgeAction action);
  ForgeShortcutBinding? conflictsWith(ForgeShortcutKey key);
}

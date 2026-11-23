import '../actions/forge_action.dart';

/// Registry for globally discoverable shell actions.
abstract class ForgeActionRegistry {
  /// Registers or replaces an action by id.
  void registerAction(ForgeAction action);

  /// Removes an action by id.
  void unregisterAction(String actionId);

  /// Gets an action by id.
  ForgeAction? getAction(String actionId);

  /// Returns all registered actions.
  List<ForgeAction> get allActions;
}

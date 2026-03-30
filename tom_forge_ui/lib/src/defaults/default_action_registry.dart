import 'dart:developer' as developer;

import '../actions/forge_action.dart';
import '../services/forge_action_registry.dart';

/// Default in-memory implementation of [ForgeActionRegistry].
class DefaultActionRegistry implements ForgeActionRegistry {
  static bool debugEnabled = false;

  final Map<String, ForgeAction> _actions = {};

  @override
  void registerAction(ForgeAction action) {
    if (_actions.containsKey(action.id)) {
      developer.log(
        'Duplicate action ID: ${action.id} — overwriting previous registration',
        name: 'ForgeActionRegistry',
      );
    }
    _actions[action.id] = action;
  }

  @override
  void unregisterAction(String actionId) {
    _actions.remove(actionId);
  }

  @override
  ForgeAction? getAction(String actionId) => _actions[actionId];

  @override
  List<ForgeAction> get allActions => List.unmodifiable(_actions.values);
}

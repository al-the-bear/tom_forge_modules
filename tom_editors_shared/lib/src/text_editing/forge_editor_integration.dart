import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../forge_bridge/forge_action.dart';
import '../forge_bridge/forge_shortcut_key.dart';
import 'forge_text_context.dart';
import 'forge_text_settings.dart';

/// Debug flag for ForgeEditorIntegration.
bool kForgeEditorIntegrationDebug = false;

void _log(String message) {
  if (kForgeEditorIntegrationDebug) {
    // ignore: avoid_print
    print('[ForgeEditorIntegration] $message');
  }
}

/// Callback signature for when the text content changes.
typedef TextChangeCallback = void Function(String newText);

/// Callback signature for when the selection changes.
typedef SelectionChangeCallback = void Function(TextSelection newSelection);

/// Abstract interface for integrating text editors with the Forge shell.
///
/// Provides a bidirectional contract:
/// - Shell can query editor state and invoke actions
/// - Editor notifies shell of changes
///
/// See [BaseStandaloneIntegration] for a base implementation suitable
/// for standalone text fields.
abstract class ForgeEditorIntegration {
  /// The current text editing context (text, selection, cursor info).
  ForgeTextContext get textContext;

  /// Current text settings applied to this editor.
  ForgeTextSettings get textSettings;

  /// Updates the text settings for this editor.
  set textSettings(ForgeTextSettings settings);

  /// Registers a callback for text content changes.
  void addTextChangeListener(TextChangeCallback callback);

  /// Removes a previously registered text change callback.
  void removeTextChangeListener(TextChangeCallback callback);

  /// Registers a callback for selection changes.
  void addSelectionChangeListener(SelectionChangeCallback callback);

  /// Removes a previously registered selection change callback.
  void removeSelectionChangeListener(SelectionChangeCallback callback);

  /// Returns the list of actions this editor supports.
  ///
  /// Standard editing actions (cut, copy, paste, undo, redo, select all)
  /// should be included. Editor-specific actions may extend this list.
  List<ForgeAction> get supportedActions;

  /// Executes the action identified by [actionId].
  ///
  /// Returns `true` if the action was handled, `false` otherwise.
  bool executeAction(String actionId);

  /// Whether the specified action is currently enabled.
  ///
  /// For example, "copy" might be disabled when nothing is selected.
  bool isActionEnabled(String actionId);

  /// Returns the keyboard shortcut binding for an action, if any.
  ForgeShortcutKey? getShortcutForAction(String actionId);

  /// Requests focus for this editor.
  void requestFocus();

  /// Whether this editor currently has focus.
  bool get hasFocus;

  /// Sets the text content programmatically.
  ///
  /// If [addToUndoHistory] is true, this change can be undone.
  void setText(String text, {bool addToUndoHistory = true});

  /// Sets the selection programmatically.
  void setSelection(TextSelection selection);

  /// Inserts text at the current cursor position (or replaces selection).
  void insertText(String text);

  /// Registers an action [handler] for the given [actionId].
  ///
  /// If [isEnabled] is provided, it controls whether the action can be
  /// invoked.  Re-registering the same [actionId] replaces the previous
  /// handler.
  void registerAction(
    String actionId,
    VoidCallback handler, {
    bool Function()? isEnabled,
  });

  /// Unregisters the action with the given [actionId].
  void unregisterAction(String actionId);

  /// Disposes resources held by this integration.
  void dispose();
}

/// Mixin providing standard action logic for [ForgeEditorIntegration].
mixin StandardActionsMixin on ForgeEditorIntegration {
  /// Map of action IDs to their handlers.
  final Map<String, VoidCallback> _actionHandlers = {};

  /// Map of action IDs to their enabled-state queries.
  final Map<String, bool Function()> _actionEnabledQueries = {};

  /// Register a standard action with its handler and enabled query.
  @override
  void registerAction(
    String actionId,
    VoidCallback handler, {
    bool Function()? isEnabled,
  }) {
    _log('Registering action: $actionId');
    _actionHandlers[actionId] = handler;
    if (isEnabled != null) {
      _actionEnabledQueries[actionId] = isEnabled;
    }
  }

  /// Unregister an action.
  @override
  void unregisterAction(String actionId) {
    _log('Unregistering action: $actionId');
    _actionHandlers.remove(actionId);
    _actionEnabledQueries.remove(actionId);
  }

  @override
  bool executeAction(String actionId) {
    final handler = _actionHandlers[actionId];
    if (handler != null) {
      _log('Executing action: $actionId');
      handler();
      return true;
    }
    _log('Action not found: $actionId');
    return false;
  }

  @override
  bool isActionEnabled(String actionId) {
    final query = _actionEnabledQueries[actionId];
    if (query != null) {
      return query();
    }
    // Default: enabled if handler exists
    return _actionHandlers.containsKey(actionId);
  }
}

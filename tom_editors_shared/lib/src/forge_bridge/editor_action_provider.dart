import 'editor_capabilities.dart';
import 'editor_state_snapshot.dart';

/// Contract between the Forge shell and any editor for standard actions.
///
/// The shell calls these methods on the ACTIVE editor only — never on
/// inactive editors. This eliminates stale-closure and single-slot
/// registry problems.
///
/// Every [ForgeEditor] subclass implements this interface. The shell
/// routes action requests (from the action bar, keyboard shortcuts,
/// or the command palette) through the active editor's provider.
///
/// ## Dispatch flow
///
/// ```
/// shell.executeAction(actionId)
///   → editor = systemState.activeEditor
///   → if editor == null → return false
///   → if !editor.isActionEnabled(actionId) → return false
///   → return editor.executeAction(actionId)
/// ```
///
/// ## Enablement flow
///
/// ```
/// scaffold.build()
///   → for each actionId in actionBarConfig:
///       1. snapshot = activeEditor.stateSnapshot
///       2. enabled = StandardEditingActions.enablementRule(actionId)(snapshot)
///       3. render button with enabled state
/// ```
abstract interface class EditorActionProvider {
  /// The set of action IDs this editor can ever handle.
  ///
  /// This is a static capability list — it does NOT change based on
  /// editor state. Use [isActionEnabled] for dynamic availability.
  ///
  /// Example: A Dart editor returns all 11 standard IDs plus
  /// dart-specific ones. A YAML tree editor (non-text-mode) returns
  /// only undo/redo.
  Set<String> get supportedActionIds;

  /// Whether [actionId] is currently enabled given the editor's state.
  ///
  /// Called by the shell/action bar on every rebuild to determine button
  /// active state. Must be cheap — no async, no side effects.
  ///
  /// Returns false if [actionId] is not in [supportedActionIds].
  bool isActionEnabled(String actionId);

  /// Execute the action. Returns true if handled.
  ///
  /// The shell only calls this when [isActionEnabled] returns true.
  /// The editor performs the operation on its own internal state.
  bool executeAction(String actionId);

  /// Structured capabilities for the shell to query without knowing
  /// action IDs.
  EditorCapabilities get capabilities;

  /// Current state snapshot for action enablement decisions.
  ///
  /// Updated by the editor whenever relevant state changes.
  /// The shell reads this to evaluate enablement rules.
  EditorStateSnapshot get stateSnapshot;
}

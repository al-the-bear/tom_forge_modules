import 'dart:async';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';

/// Global shortcut management, rebinding, and chord state tracking.
abstract class ForgeShortcutManager {
  List<ForgeShortcutBinding> get allBindings;
  void rebind(ForgeAction action, ForgeShortcutKey key);
  void resetToDefault(ForgeAction action);
  ForgeShortcutBinding? conflictsWith(ForgeShortcutKey key);
  ForgeShortcutBinding? getBinding(String actionId);

  // ── Chord support ──

  /// All chord bindings registered in this manager.
  List<ForgeShortcutBinding> get chordBindings;

  /// Whether the manager is currently waiting for a second chord key.
  bool get isChordPending;

  /// The first key that was pressed to start a chord, or null.
  ForgeShortcutKey? get pendingChordFirstKey;

  /// Available chord completions for the current pending first key.
  List<ForgeShortcutBinding> get pendingChordCompletions;

  /// Stream that fires when chord state changes (entered/exited/completed).
  Stream<ForgeChordEvent> get onChordStateChanged;

  /// Attempt to match a key press against chord bindings.
  ///
  /// Returns the matched binding if a chord is completed, or null.
  /// Call this before normal shortcut dispatch.
  ForgeShortcutBinding? handleKeyForChord(ForgeShortcutKey key);

  /// Cancel any pending chord.
  void cancelChord();
}

/// Event describing a chord state transition.
class ForgeChordEvent {
  /// The type of chord state change.
  final ForgeChordState state;

  /// The first key that started the chord (for [ForgeChordState.entered]).
  final ForgeShortcutKey? firstKey;

  /// Available completions (for [ForgeChordState.entered]).
  final List<ForgeShortcutBinding> completions;

  /// The binding that was executed (for [ForgeChordState.completed]).
  final ForgeShortcutBinding? executedBinding;

  const ForgeChordEvent({
    required this.state,
    this.firstKey,
    this.completions = const [],
    this.executedBinding,
  });
}

/// Chord state machine states.
enum ForgeChordState {
  /// First key pressed, waiting for second key.
  entered,

  /// Second key matched, action will be executed.
  completed,

  /// Chord was cancelled (timeout, escape, or non-matching key).
  cancelled,
}

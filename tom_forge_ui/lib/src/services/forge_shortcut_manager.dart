import 'dart:async';

import 'package:flutter/services.dart';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/forge_shortcut_menu.dart';

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

  // ── Shortcut menu support ──

  /// All registered shortcut menus.
  List<ForgeShortcutMenu> get allMenus;

  /// Returns the menu for [triggerKey], or null if none is registered.
  ForgeShortcutMenu? getMenuForTrigger(LogicalKeyboardKey triggerKey);

  /// Register a shortcut menu.
  void registerMenu(ForgeShortcutMenu menu);

  /// The currently open menu, or null.
  ForgeShortcutMenu? get activeMenu;

  /// Stream that fires when a shortcut menu opens or closes.
  Stream<ForgeShortcutMenuEvent> get onMenuStateChanged;

  /// Open the menu for [triggerKey]. Returns true if a menu was found.
  bool openMenu(LogicalKeyboardKey triggerKey);

  /// Handle a follow-up key press inside an open menu.
  ///
  /// Returns the matched entry if found, or null.
  ForgeShortcutMenuEntry? handleMenuKey(LogicalKeyboardKey key);

  /// Close the currently open menu.
  void closeMenu();
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

/// Event describing a shortcut menu state transition.
class ForgeShortcutMenuEvent {
  /// The type of menu state change.
  final ForgeShortcutMenuState state;

  /// The menu that was opened (for [ForgeShortcutMenuState.opened]).
  final ForgeShortcutMenu? menu;

  /// The entry that was selected (for [ForgeShortcutMenuState.selected]).
  final ForgeShortcutMenuEntry? selectedEntry;

  const ForgeShortcutMenuEvent({
    required this.state,
    this.menu,
    this.selectedEntry,
  });
}

/// Shortcut menu states.
enum ForgeShortcutMenuState {
  /// Menu popup opened.
  opened,

  /// An entry was selected and will be executed.
  selected,

  /// Menu was closed without selection.
  closed,
}

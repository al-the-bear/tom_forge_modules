import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'forge_action.dart';

/// A keyboard shortcut key combination.
///
/// [primaryModifier] is the platform's command key: ⌘ on macOS, Ctrl
/// elsewhere. [control] is the Control key itself, on every platform: on
/// macOS the key beside ⌘ (VS Code's Go Back is ⌃- there), elsewhere the same
/// key as the primary modifier — so on Windows and Linux a key with
/// [control] equals the same key with [primaryModifier].
class ForgeShortcutKey {
  final LogicalKeyboardKey key;
  final bool primaryModifier;
  final bool control;
  final bool shift;
  final bool alt;

  const ForgeShortcutKey({
    required this.key,
    this.primaryModifier = false,
    this.control = false,
    this.shift = false,
    this.alt = false,
  });

  /// The key combination of [key] pressed with the modifiers in [pressed]
  /// (`HardwareKeyboard.instance.logicalKeysPressed`), or null when [key] is
  /// itself a modifier.
  static ForgeShortcutKey? fromPressed(
    LogicalKeyboardKey key,
    Set<LogicalKeyboardKey> pressed,
  ) {
    if (_modifierKeys.contains(key)) return null;
    bool any(LogicalKeyboardKey left, LogicalKeyboardKey right) =>
        pressed.contains(left) || pressed.contains(right);
    final hasControl = any(
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
    );
    final useMeta = _useMeta;
    return ForgeShortcutKey(
      key: key,
      primaryModifier: useMeta
          ? any(LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight)
          : hasControl,
      control: useMeta && hasControl,
      shift: any(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight),
      alt: any(LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight),
    );
  }

  static final _modifierKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };

  static bool get _useMeta =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  // Why: equality is on the keys a user presses on this platform, so a
  // Control binding and a primary-modifier binding of the same key collide
  // on Windows and Linux, where they are one key.
  bool get _pressesMeta => primaryModifier && _useMeta;
  bool get _pressesControl => control || (primaryModifier && !_useMeta);

  /// Returns a [SingleActivator] equivalent for this key combination.
  SingleActivator toActivator() => SingleActivator(
    key,
    meta: _pressesMeta,
    control: _pressesControl,
    shift: shift,
    alt: alt,
  );

  /// Returns a human-readable display string (e.g. "⌘K", "⌃-" or "Ctrl+K").
  String toDisplayString() {
    final useMeta = _useMeta;
    final parts = <String>[];
    if (useMeta && control) parts.add('⌃');
    if (_pressesMeta) parts.add('⌘');
    if (!useMeta && _pressesControl) parts.add('Ctrl');
    if (shift) parts.add(useMeta ? '⇧' : 'Shift');
    if (alt) parts.add(useMeta ? '⌥' : 'Alt');
    parts.add(key.keyLabel);
    return useMeta ? parts.join() : parts.join('+');
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeShortcutKey &&
      key == other.key &&
      _pressesMeta == other._pressesMeta &&
      _pressesControl == other._pressesControl &&
      shift == other.shift &&
      alt == other.alt;

  @override
  int get hashCode =>
      Object.hash(key, _pressesMeta, _pressesControl, shift, alt);

  @override
  String toString() => 'ForgeShortcutKey(${toDisplayString()})';
}

/// A two-key chord shortcut (e.g. Ctrl+K → Ctrl+C).
///
/// The user presses [firstKey], then within a timeout window presses
/// [secondKey] to trigger the bound action.
class ForgeChordKey {
  /// The first key combination that activates chord mode.
  final ForgeShortcutKey firstKey;

  /// The second key combination that completes the chord.
  final ForgeShortcutKey secondKey;

  const ForgeChordKey({required this.firstKey, required this.secondKey});

  /// Returns a display string like "⌘K ⌘C" or "Ctrl+K Ctrl+C".
  String toDisplayString() =>
      '${firstKey.toDisplayString()} ${secondKey.toDisplayString()}';

  @override
  bool operator ==(Object other) =>
      other is ForgeChordKey &&
      firstKey == other.firstKey &&
      secondKey == other.secondKey;

  @override
  int get hashCode => Object.hash(firstKey, secondKey);

  @override
  String toString() => 'ForgeChordKey(${toDisplayString()})';
}

/// A binding between an action and a keyboard shortcut.
class ForgeShortcutBinding {
  final ForgeAction action;
  final ForgeShortcutKey key;

  /// If non-null, this binding uses a two-key chord instead of [key].
  final ForgeChordKey? chord;

  /// Optional context constraint (e.g. 'editorFocus').
  final String? context;

  const ForgeShortcutBinding({
    required this.action,
    required this.key,
    this.chord,
    this.context,
  });

  /// Whether this binding is a chord (two-key) shortcut.
  bool get isChord => chord != null;

  /// Display string for the effective shortcut.
  String get displayString => chord?.toDisplayString() ?? key.toDisplayString();
}

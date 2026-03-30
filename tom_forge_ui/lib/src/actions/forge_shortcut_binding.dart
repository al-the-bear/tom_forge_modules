import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'forge_action.dart';

/// A keyboard shortcut key combination.
class ForgeShortcutKey {
  final LogicalKeyboardKey key;
  final bool primaryModifier;
  final bool shift;
  final bool alt;

  const ForgeShortcutKey({
    required this.key,
    this.primaryModifier = false,
    this.shift = false,
    this.alt = false,
  });

  /// Returns a [SingleActivator] equivalent for this key combination.
  SingleActivator toActivator() {
    final useMeta =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    return SingleActivator(
      key,
      meta: primaryModifier && useMeta,
      control: primaryModifier && !useMeta,
      shift: shift,
      alt: alt,
    );
  }

  /// Returns a human-readable display string (e.g. "⌘K" or "Ctrl+K").
  String toDisplayString() {
    final useMeta =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final parts = <String>[];
    if (primaryModifier) parts.add(useMeta ? '⌘' : 'Ctrl');
    if (shift) parts.add(useMeta ? '⇧' : 'Shift');
    if (alt) parts.add(useMeta ? '⌥' : 'Alt');
    parts.add(key.keyLabel);
    return useMeta ? parts.join() : parts.join('+');
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeShortcutKey &&
      key == other.key &&
      primaryModifier == other.primaryModifier &&
      shift == other.shift &&
      alt == other.alt;

  @override
  int get hashCode => Object.hash(key, primaryModifier, shift, alt);

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

  const ForgeChordKey({
    required this.firstKey,
    required this.secondKey,
  });

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

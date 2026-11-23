import 'package:tom_editors_shared/text_types.dart' show ForgeShortcutKey;

import 'forge_action.dart';

// The one declaration of ForgeShortcutKey is tom_editors_shared's
// (webview-free `text_types.dart`); the shell re-exports it.
export 'package:tom_editors_shared/text_types.dart' show ForgeShortcutKey;

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

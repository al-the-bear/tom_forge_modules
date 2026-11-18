import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether debug logging is enabled for forge_shortcut_key operations.
bool kForgeShortcutKeyDebug = false;

void _log(String message) {
  if (kForgeShortcutKeyDebug) {
    // ignore: avoid_print
    print('[ForgeShortcutKey] $message');
  }
}

/// A keyboard shortcut key combination: the one declaration Forge's shell
/// (`tom_forge_ui`, which re-exports it) and its editors share.
///
/// [primaryModifier] is the platform's command key: ⌘ on macOS, Ctrl
/// elsewhere. [control] is the Control key itself, on every platform: on
/// macOS the key beside ⌘ (VS Code's Go Back is ⌃- there), elsewhere the same
/// key as the primary modifier — so on Windows and Linux a key with
/// [control] equals the same key with [primaryModifier].
///
/// ```dart
/// // Cmd+S on macOS, Ctrl+S on Windows/Linux
/// ForgeShortcutKey(key: LogicalKeyboardKey.keyS, primaryModifier: true)
///
/// // Cmd+Shift+Z on macOS, Ctrl+Shift+Z on Windows/Linux
/// ForgeShortcutKey(
///   key: LogicalKeyboardKey.keyZ,
///   primaryModifier: true,
///   shift: true,
/// )
/// ```
class ForgeShortcutKey {
  /// The primary key for this shortcut.
  final LogicalKeyboardKey key;

  /// Whether the primary modifier is required: Command (⌘) on macOS,
  /// Control elsewhere.
  final bool primaryModifier;

  /// Whether the Control key itself is required (⌃ on macOS).
  final bool control;

  /// Whether the Shift key is required.
  final bool shift;

  /// Whether the Alt/Option key is required.
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

  /// Whether the primary modifier is Cmd (meta) here, as on macOS, rather
  /// than Ctrl. The shell decides it the same way, from the target platform.
  static bool get primaryIsMeta => _useMeta;

  static bool get _useMeta =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  // Why: equality is on the keys a user presses on this platform, so a
  // Control binding and a primary-modifier binding of the same key collide
  // on Windows and Linux, where they are one key.
  bool get _pressesMeta => primaryModifier && _useMeta;
  bool get _pressesControl => control || (primaryModifier && !_useMeta);

  /// Returns a [SingleActivator] equivalent for this key combination.
  SingleActivator toActivator() {
    _log(
      'toActivator: key=${key.debugName}, primary=$primaryModifier, '
      'control=$control, shift=$shift, alt=$alt, meta=$_useMeta',
    );
    return SingleActivator(
      key,
      meta: _pressesMeta,
      control: _pressesControl,
      shift: shift,
      alt: alt,
    );
  }

  /// Returns a human-readable display string (e.g. "⌘K", "⌃-" or "Ctrl+K").
  String toDisplayString() {
    final useMeta = _useMeta;
    final parts = <String>[];
    if (useMeta && control) parts.add('⌃');
    if (_pressesMeta) parts.add('⌘');
    if (!useMeta && _pressesControl) parts.add('Ctrl');
    if (shift) parts.add(useMeta ? '⇧' : 'Shift');
    if (alt) parts.add(useMeta ? '⌥' : 'Alt');
    parts.add(_keyLabel(key));
    return useMeta ? parts.join() : parts.join('+');
  }

  /// The key's label, or its debug name for a key without one.
  static String _keyLabel(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.isNotEmpty) return label;
    return key.debugName ?? '?';
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

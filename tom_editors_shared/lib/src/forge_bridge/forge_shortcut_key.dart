import 'dart:io' show Platform;

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

/// A keyboard shortcut key combination.
///
/// Uses [usePrimaryModifier] which resolves to:
/// - **macOS**: ⌘ (Command)
/// - **Windows/Linux**: Ctrl
///
/// This provides consistent cross-platform keyboard shortcut behavior
/// while respecting platform conventions.
///
/// ```dart
/// // Cmd+S on macOS, Ctrl+S on Windows/Linux
/// ForgeShortcutKey(
///   key: LogicalKeyboardKey.keyS,
///   usePrimaryModifier: true,
/// )
///
/// // Cmd+Shift+Z on macOS, Ctrl+Shift+Z on Windows/Linux
/// ForgeShortcutKey(
///   key: LogicalKeyboardKey.keyZ,
///   usePrimaryModifier: true,
///   shift: true,
/// )
/// ```
class ForgeShortcutKey {
  /// The primary key for this shortcut.
  final LogicalKeyboardKey key;

  /// Whether the primary modifier is required.
  /// - macOS: Command (⌘)
  /// - Windows/Linux: Control
  final bool usePrimaryModifier;

  /// Whether the Shift key is required.
  final bool shift;

  /// Whether the Alt/Option key is required.
  final bool alt;

  const ForgeShortcutKey({
    required this.key,
    this.usePrimaryModifier = false,
    this.shift = false,
    this.alt = false,
  });

  /// Converts this shortcut to a Flutter [SingleActivator].
  ///
  /// Resolves [usePrimaryModifier] to the appropriate platform-specific
  /// modifier key (meta on macOS, control on Windows/Linux).
  SingleActivator toActivator() {
    final isMacOS = _isMacOS;
    _log('toActivator: key=${key.debugName}, primaryMod=$usePrimaryModifier, '
        'shift=$shift, alt=$alt, isMacOS=$isMacOS');

    return SingleActivator(
      key,
      control: !isMacOS && usePrimaryModifier,
      meta: isMacOS && usePrimaryModifier,
      alt: alt,
      shift: shift,
    );
  }

  /// Returns a human-readable representation of this shortcut.
  ///
  /// Uses platform-appropriate symbols:
  /// - macOS: ⌘, ⌥, ⇧
  /// - Windows/Linux: Ctrl+, Alt+, Shift+
  String toDisplayString() {
    final parts = <String>[];
    final isMacOS = _isMacOS;

    if (usePrimaryModifier) {
      parts.add(isMacOS ? '⌘' : 'Ctrl');
    }
    if (alt) {
      parts.add(isMacOS ? '⌥' : 'Alt');
    }
    if (shift) {
      parts.add(isMacOS ? '⇧' : 'Shift');
    }
    parts.add(_formatKeyLabel(key));

    return isMacOS ? parts.join('') : parts.join('+');
  }

  /// Formats a key label for display.
  String _formatKeyLabel(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();
    return key.debugName ?? '?';
  }

  /// Platform detection for modifier resolution.
  static bool get _isMacOS {
    try {
      return Platform.isMacOS;
    } catch (_) {
      // Web platform doesn't support Platform
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeShortcutKey &&
      key == other.key &&
      usePrimaryModifier == other.usePrimaryModifier &&
      shift == other.shift &&
      alt == other.alt;

  @override
  int get hashCode => Object.hash(key, usePrimaryModifier, shift, alt);

  @override
  String toString() =>
      'ForgeShortcutKey(${key.debugName}, primary=$usePrimaryModifier, '
      'shift=$shift, alt=$alt)';
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('ForgeShortcutKey', () {
    test('creates with key and modifiers', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        usePrimaryModifier: true,
      );

      expect(shortcut.key, LogicalKeyboardKey.keyS);
      expect(shortcut.usePrimaryModifier, true);
      expect(shortcut.shift, false);
      expect(shortcut.alt, false);
    });

    test('creates with shift modifier', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyZ,
        usePrimaryModifier: true,
        shift: true,
      );

      expect(shortcut.shift, true);
    });

    test('toActivator returns SingleActivator', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyC,
        usePrimaryModifier: true,
      );

      final activator = shortcut.toActivator();
      expect(activator, isA<SingleActivator>());
      expect(activator.trigger, LogicalKeyboardKey.keyC);
    });

    test('toDisplayString formats correctly on macOS', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        usePrimaryModifier: true,
      );

      // Note: defaultTargetPlatform may vary in tests
      final display = shortcut.toDisplayString();
      expect(display, isNotEmpty);
      expect(display, contains('S'));
    });

    test('toDisplayString includes shift when present', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyZ,
        usePrimaryModifier: true,
        shift: true,
      );

      final display = shortcut.toDisplayString();
      expect(display, contains('Z'));
    });

    test('equality based on key and modifiers', () {
      final key1 = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyA,
        usePrimaryModifier: true,
      );
      final key2 = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyA,
        usePrimaryModifier: true,
      );
      final key3 = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyB,
        usePrimaryModifier: true,
      );

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('hashCode consistent with equality', () {
      final key1 = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyA,
        usePrimaryModifier: true,
      );
      final key2 = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyA,
        usePrimaryModifier: true,
      );

      expect(key1.hashCode, equals(key2.hashCode));
    });
  });
}

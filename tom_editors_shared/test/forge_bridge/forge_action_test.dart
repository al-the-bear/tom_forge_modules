import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('ForgeMenuLocation', () {
    test('has expected values', () {
      expect(ForgeMenuLocation.values, contains(ForgeMenuLocation.file));
      expect(ForgeMenuLocation.values, contains(ForgeMenuLocation.edit));
      expect(ForgeMenuLocation.values, contains(ForgeMenuLocation.view));
      expect(ForgeMenuLocation.values, contains(ForgeMenuLocation.commandPalette));
    });
  });

  group('ForgeAction', () {
    test('creates with required fields', () {
      final action = ForgeAction(
        id: 'test.action',
        label: 'Test Action',
        execute: (_) async => null,
        isEnabled: () => true,
        isVisible: () => true,
      );

      expect(action.id, 'test.action');
      expect(action.label, 'Test Action');
      expect(action.defaultShortcut, isNull);
      expect(action.menu, ForgeMenuLocation.commandPalette);
    });

    test('creates with all fields', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyT,
        primaryModifier: true,
      );
      bool executed = false;

      final action = ForgeAction(
        id: 'test.full',
        label: 'Full Action',
        defaultShortcut: shortcut,
        menu: ForgeMenuLocation.edit,
        execute: (_) async {
          executed = true;
          return null;
        },
        isEnabled: () => true,
        isVisible: () => true,
      );

      expect(action.id, 'test.full');
      expect(action.defaultShortcut, shortcut);
      expect(action.menu, ForgeMenuLocation.edit);

      action.execute({});
      expect(executed, true);
    });

    test('editing factory creates sync action', () {
      bool executed = false;

      final action = ForgeAction.editing(
        id: 'test.edit',
        label: 'Edit Action',
        execute: () {
          executed = true;
          return true;
        },
        isEnabled: () => true,
      );

      expect(action.id, 'test.edit');
      expect(action.menu, ForgeMenuLocation.edit);

      action.execute({});
      expect(executed, true);
    });

    test('editing factory with shortcut', () {
      final shortcut = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyE,
        primaryModifier: true,
      );

      final action = ForgeAction.editing(
        id: 'test.shortcut',
        label: 'Shortcut Action',
        shortcut: shortcut,
        execute: () => true,
        isEnabled: () => true,
      );

      expect(action.defaultShortcut, shortcut);
    });

    test('isEnabled returns correct state', () {
      bool enabled = false;

      final action = ForgeAction(
        id: 'test.enabled',
        label: 'Test',
        execute: (_) async => null,
        isEnabled: () => enabled,
        isVisible: () => true,
      );

      expect(action.isEnabled(), false);
      enabled = true;
      expect(action.isEnabled(), true);
    });

    test('isVisible returns correct state', () {
      bool visible = true;

      final action = ForgeAction(
        id: 'test.visible',
        label: 'Test',
        execute: (_) async => null,
        isEnabled: () => true,
        isVisible: () => visible,
      );

      expect(action.isVisible(), true);
      visible = false;
      expect(action.isVisible(), false);
    });

    test('toString includes id and menu', () {
      final action = ForgeAction(
        id: 'my.action',
        label: 'My Action',
        execute: (_) async => null,
        isEnabled: () => true,
        isVisible: () => true,
      );
      final str = action.toString();

      expect(str, contains('my.action'));
    });
  });
}

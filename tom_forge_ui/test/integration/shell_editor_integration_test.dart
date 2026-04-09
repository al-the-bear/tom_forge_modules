import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart' as shared;
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  group('ShellEditorIntegration', () {
    late DefaultShellApi shellApi;

    setUp(() {
      shellApi = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test Shell',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
    });

    test('registerAction adds action to shell action registry', () {
      final integration = ShellEditorIntegration(
        shellApi: shellApi,
        editorId: 'md-editor-1',
        editorTypeId: 'md',
      )..descriptors = [
          ...shared.MdEditorActions.descriptors,
          ...shared.StandardEditingActions.descriptors,
        ];
      final action = shared.ForgeAction.editing(
        id: shared.StandardEditingActions.cutActionId,
        label: 'Cut',
        shortcut: const shared.ForgeShortcutKey(
          key: LogicalKeyboardKey.keyX,
          usePrimaryModifier: true,
        ),
        execute: () => true,
        isEnabled: () => true,
      );

      integration.registerAction(action.id, () {
        action.execute({});
      });

      expect(shellApi.actionRegistry.getAction(action.id), isNotNull);
    });

    test('shortcut rebinding is returned by integration', () {
      final integration = ShellEditorIntegration(
        shellApi: shellApi,
        editorId: 'dart-editor-1',
        editorTypeId: 'dart',
      );

      final action = shared.ForgeAction.editing(
        id: 'editor.save',
        label: 'Save',
        shortcut: const shared.ForgeShortcutKey(
          key: LogicalKeyboardKey.keyS,
          usePrimaryModifier: true,
        ),
        execute: () => true,
        isEnabled: () => true,
      );

      integration.registerShellAction(action);

      final shellAction = shellApi.actionRegistry.getAction(action.id);
      expect(shellAction, isNotNull);

      const rebound = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
        shift: true,
      );
      shellApi.shortcuts.rebind(shellAction!, rebound);

      final resolved = integration.getShortcutForAction(action.id);
      expect(resolved, isNotNull);
      expect(resolved!.key, equals(LogicalKeyboardKey.keyS));
      expect(resolved.usePrimaryModifier, isTrue);
      expect(resolved.shift, isTrue);
    });

    test('context menu actions are discovered from shell', () {
      final integration = ShellEditorIntegration(
        shellApi: shellApi,
        editorId: 'yaml-editor-1',
        editorTypeId: 'yaml',
      );

      final contextAction = shared.ForgeAction.editing(
        id: 'yaml.addKey',
        label: 'Add Key',
        showInContextMenu: true,
        execute: () => true,
        isEnabled: () => true,
      );

      integration.registerShellAction(contextAction);
      final actions = integration.getContextMenuActions();

      expect(actions.map((a) => a.id), contains('yaml.addKey'));
    });

    test('onContextChanged updates shell system state context', () {
      final integration = ShellEditorIntegration(
        shellApi: shellApi,
        editorId: 'md-editor-context',
        editorTypeId: 'md',
      );
      final context = shared.TextEditingContextImpl.withValues(
        text: '# Hello',
        selections: const [TextSelection.collapsed(offset: 2)],
        canUndo: true,
        canRedo: false,
      );

      integration.onContextChanged(context);

      final stored = shellApi.systemState.getEditorContext('md-editor-context');
      expect(stored, isNotNull);
      expect(stored!.text, equals(context.text));
      expect(stored.cursorOffset, equals(context.cursorOffset));
    });

    test('text settings persist per editor type through shell config', () {
      final integration = ShellEditorIntegration(
        shellApi: shellApi,
        editorId: 'md-editor-settings',
        editorTypeId: 'md',
      );

      const updated = shared.ForgeTextSettings(
        fontFamily: 'Fira Code',
        fontSize: 15,
        tabSize: 4,
      );
      integration.textSettings = updated;

      final second = ShellEditorIntegration(
        shellApi: shellApi,
        editorId: 'md-editor-settings-2',
        editorTypeId: 'md',
      );

      expect(second.textSettings, equals(updated));
    });

    test('executeAction recursion guard prevents stack overflow', () {
      // Simulate the bug: a placeholder action whose execute callback
      // calls shellApi.executeAction with its own ID.
      int callCount = 0;
      final recursiveAction = ForgeAction(
        id: 'forge.edit.copy',
        label: 'Copy',
        execute: (_) async {
          callCount++;
          shellApi.executeAction('forge.edit.copy');
          return null;
        },
        isEnabled: () => true,
        isVisible: () => true,
      );

      shellApi.actionRegistry.registerAction(recursiveAction);
      final result = shellApi.executeAction('forge.edit.copy');

      // Should execute once (the outer call), but the recursive inner call
      // should be short-circuited by the guard.
      expect(result, isTrue);
      expect(callCount, equals(1));
    });
  });
}

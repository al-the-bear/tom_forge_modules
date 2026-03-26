import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('BaseStandaloneIntegration', () {
    late TextEditingController controller;
    late FocusNode focusNode;
    late BaseStandaloneIntegration integration;

    setUp(() {
      controller = TextEditingController(text: 'Hello World');
      focusNode = FocusNode();
      integration = BaseStandaloneIntegration(
        controller: controller,
        focusNode: focusNode,
      );
    });

    tearDown(() {
      integration.dispose();
      controller.dispose();
      focusNode.dispose();
    });

    test('creates with controller and focusNode', () {
      expect(integration.textContext.text, 'Hello World');
    });

    test('textContext reflects controller state', () {
      controller.text = 'Changed';
      controller.selection = const TextSelection.collapsed(offset: 7);

      final context = integration.textContext;
      expect(context.text, 'Changed');
      expect(context.cursorOffset, 7);
    });

    test('hasFocus reflects focusNode state', () {
      expect(integration.hasFocus, false);
    });

    test('supportedActions returns six standard actions', () {
      final actions = integration.supportedActions;
      expect(actions.length, 6);
    });

    test('getShortcutForAction returns correct shortcuts', () {
      expect(
        integration.getShortcutForAction(StandardEditingActions.cutActionId),
        StandardEditingActions.cutShortcut,
      );
      expect(
        integration.getShortcutForAction(StandardEditingActions.copyActionId),
        StandardEditingActions.copyShortcut,
      );
      expect(
        integration.getShortcutForAction('unknown'),
        isNull,
      );
    });

    test('setText updates controller', () {
      integration.setText('New Text');
      expect(controller.text, 'New Text');
    });

    test('setSelection updates controller', () {
      const selection = TextSelection(baseOffset: 0, extentOffset: 5);
      integration.setSelection(selection);
      expect(controller.selection, selection);
    });

    test('insertText replaces selection', () {
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      integration.insertText('Everyone');
      expect(controller.text, 'Hello Everyone');
    });

    test('insertText at cursor position', () {
      controller.selection = const TextSelection.collapsed(offset: 5);
      integration.insertText(' Beautiful');
      expect(controller.text, 'Hello Beautiful World');
    });

    test('executeAction returns true for known actions', () {
      expect(
        integration.executeAction(StandardEditingActions.selectAllActionId),
        true,
      );
    });

    test('executeAction returns false for unknown actions', () {
      expect(integration.executeAction('unknown.action'), false);
    });

    group('isActionEnabled', () {
      test('cut enabled when selection exists', () {
        controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
        expect(
          integration.isActionEnabled(StandardEditingActions.cutActionId),
          true,
        );
      });

      test('cut disabled when no selection', () {
        controller.selection = const TextSelection.collapsed(offset: 0);
        expect(
          integration.isActionEnabled(StandardEditingActions.cutActionId),
          false,
        );
      });

      test('selectAll enabled when text exists', () {
        expect(
          integration.isActionEnabled(StandardEditingActions.selectAllActionId),
          true,
        );
      });

      test('selectAll disabled when empty', () {
        controller.text = '';
        expect(
          integration.isActionEnabled(StandardEditingActions.selectAllActionId),
          false,
        );
      });

      test('undo disabled initially', () {
        expect(
          integration.isActionEnabled(StandardEditingActions.undoActionId),
          false,
        );
      });

      test('redo disabled initially', () {
        expect(
          integration.isActionEnabled(StandardEditingActions.redoActionId),
          false,
        );
      });
    });

    group('undo/redo', () {
      test('undo enabled after text change', () {
        controller.text = 'Changed';
        expect(
          integration.isActionEnabled(StandardEditingActions.undoActionId),
          true,
        );
      });

      test('undo restores previous text', () {
        final originalText = controller.text;
        controller.text = 'Changed';
        integration.executeAction(StandardEditingActions.undoActionId);
        expect(controller.text, originalText);
      });

      test('redo enabled after undo', () {
        controller.text = 'Changed';
        integration.executeAction(StandardEditingActions.undoActionId);
        expect(
          integration.isActionEnabled(StandardEditingActions.redoActionId),
          true,
        );
      });

      test('redo restores undone text', () {
        controller.text = 'Changed';
        integration.executeAction(StandardEditingActions.undoActionId);
        integration.executeAction(StandardEditingActions.redoActionId);
        expect(controller.text, 'Changed');
      });

      test('new change clears redo stack', () {
        controller.text = 'First';
        integration.executeAction(StandardEditingActions.undoActionId);
        controller.text = 'Second';
        expect(
          integration.isActionEnabled(StandardEditingActions.redoActionId),
          false,
        );
      });
    });

    group('listeners', () {
      test('text change listener called on text change', () {
        String? receivedText;
        integration.addTextChangeListener((text) => receivedText = text);

        controller.text = 'New Text';
        expect(receivedText, 'New Text');
      });

      test('selection change listener called on selection change', () {
        TextSelection? receivedSelection;
        integration.addSelectionChangeListener((sel) => receivedSelection = sel);

        controller.selection = const TextSelection.collapsed(offset: 5);
        expect(receivedSelection?.baseOffset, 5);
      });

      test('removeTextChangeListener stops notifications', () {
        int callCount = 0;
        void listener(String text) => callCount++;

        integration.addTextChangeListener(listener);
        controller.text = 'A';
        expect(callCount, 1);

        integration.removeTextChangeListener(listener);
        controller.text = 'B';
        expect(callCount, 1);
      });

      test('removeSelectionChangeListener stops notifications', () {
        int callCount = 0;
        void listener(TextSelection sel) => callCount++;

        integration.addSelectionChangeListener(listener);
        controller.selection = const TextSelection.collapsed(offset: 1);
        expect(callCount, 1);

        integration.removeSelectionChangeListener(listener);
        controller.selection = const TextSelection.collapsed(offset: 2);
        expect(callCount, 1);
      });
    });

    test('textSettings can be updated', () {
      const newSettings = ForgeTextSettings(fontSize: 20);
      integration.textSettings = newSettings;
      expect(integration.textSettings.fontSize, 20);
    });

    test('setText with addToUndoHistory false skips undo', () {
      integration.setText('No Undo', addToUndoHistory: false);
      expect(
        integration.isActionEnabled(StandardEditingActions.undoActionId),
        false,
      );
    });

    test('textContext reflects undo/redo state', () {
      expect(integration.textContext.canUndo, false);
      expect(integration.textContext.canRedo, false);

      controller.text = 'Changed';
      expect(integration.textContext.canUndo, true);

      integration.executeAction(StandardEditingActions.undoActionId);
      expect(integration.textContext.canRedo, true);
    });
  });
}

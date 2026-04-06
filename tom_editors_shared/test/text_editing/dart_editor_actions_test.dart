import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('DartEditorActions', () {
    group('action IDs', () {
      test('has expected action IDs', () {
        expect(DartEditorActions.triggerCompletionActionId,
            'dart.triggerCompletion');
        expect(DartEditorActions.openReferenceActionId, 'dart.openReference');
        expect(DartEditorActions.toggleCommentActionId, 'dart.toggleComment');
        expect(DartEditorActions.deleteLineActionId, 'dart.deleteLine');
        expect(DartEditorActions.duplicateLineActionId, 'dart.duplicateLine');
        expect(DartEditorActions.moveLineUpActionId, 'dart.moveLineUp');
        expect(DartEditorActions.moveLineDownActionId, 'dart.moveLineDown');
      });

      test('all action IDs start with dart. prefix', () {
        final ids = [
          DartEditorActions.triggerCompletionActionId,
          DartEditorActions.openReferenceActionId,
          DartEditorActions.toggleCommentActionId,
          DartEditorActions.deleteLineActionId,
          DartEditorActions.duplicateLineActionId,
          DartEditorActions.moveLineUpActionId,
          DartEditorActions.moveLineDownActionId,
        ];
        for (final id in ids) {
          expect(id, startsWith('dart.'), reason: 'Action $id should start with dart.');
        }
      });
    });

    group('shortcuts', () {
      test('triggerCompletion uses Ctrl+Space', () {
        final shortcut = DartEditorActions.triggerCompletionShortcut;
        expect(shortcut.key, LogicalKeyboardKey.space);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('triggerCompletion alt1 uses Alt+Space', () {
        final shortcut = DartEditorActions.triggerCompletionAltShortcut1;
        expect(shortcut.key, LogicalKeyboardKey.space);
        expect(shortcut.alt, true);
        expect(shortcut.usePrimaryModifier, false);
      });

      test('triggerCompletion alt2 uses Ctrl+I', () {
        final shortcut = DartEditorActions.triggerCompletionAltShortcut2;
        expect(shortcut.key, LogicalKeyboardKey.keyI);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('triggerCompletionAltShortcuts contains both alternatives', () {
        expect(DartEditorActions.triggerCompletionAltShortcuts, hasLength(2));
        expect(DartEditorActions.triggerCompletionAltShortcuts,
            contains(DartEditorActions.triggerCompletionAltShortcut1));
        expect(DartEditorActions.triggerCompletionAltShortcuts,
            contains(DartEditorActions.triggerCompletionAltShortcut2));
      });

      test('openReference has no default shortcut', () {
        final action = DartEditorActions.openReference();
        expect(action.defaultShortcut, isNull);
      });

      test('toggleComment uses Cmd/Ctrl+/', () {
        final shortcut = DartEditorActions.toggleCommentShortcut;
        expect(shortcut.key, LogicalKeyboardKey.slash);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('deleteLine uses Cmd/Ctrl+Y (concept §11.3)', () {
        final shortcut = DartEditorActions.deleteLineShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyY);
        expect(shortcut.usePrimaryModifier, true);
        expect(shortcut.shift, false);
      });

      test('duplicateLine uses Cmd/Ctrl+D', () {
        final shortcut = DartEditorActions.duplicateLineShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyD);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('moveLineUp uses Alt+ArrowUp', () {
        final shortcut = DartEditorActions.moveLineUpShortcut;
        expect(shortcut.key, LogicalKeyboardKey.arrowUp);
        expect(shortcut.alt, true);
        expect(shortcut.usePrimaryModifier, false);
      });

      test('moveLineDown uses Alt+ArrowDown', () {
        final shortcut = DartEditorActions.moveLineDownShortcut;
        expect(shortcut.key, LogicalKeyboardKey.arrowDown);
        expect(shortcut.alt, true);
        expect(shortcut.usePrimaryModifier, false);
      });
    });

    group('factory methods', () {
      test('triggerCompletion creates action with correct ID and shortcut', () {
        final action = DartEditorActions.triggerCompletion();
        expect(action.id, DartEditorActions.triggerCompletionActionId);
        expect(action.label, 'Trigger Completion');
        expect(action.defaultShortcut, DartEditorActions.triggerCompletionShortcut);
        expect(action.menu, ForgeMenuLocation.edit);
      });

      test('openReference creates action with correct ID and no shortcut', () {
        final action = DartEditorActions.openReference();
        expect(action.id, DartEditorActions.openReferenceActionId);
        expect(action.label, 'Open Reference');
        expect(action.defaultShortcut, isNull);
      });

      test('toggleComment creates action with correct ID and shortcut', () {
        final action = DartEditorActions.toggleComment();
        expect(action.id, DartEditorActions.toggleCommentActionId);
        expect(action.label, 'Toggle Comment');
        expect(action.defaultShortcut, DartEditorActions.toggleCommentShortcut);
      });

      test('deleteLine creates action with correct ID', () {
        final action = DartEditorActions.deleteLine();
        expect(action.id, DartEditorActions.deleteLineActionId);
        expect(action.label, 'Delete Line');
      });

      test('duplicateLine creates action with correct ID', () {
        final action = DartEditorActions.duplicateLine();
        expect(action.id, DartEditorActions.duplicateLineActionId);
        expect(action.label, 'Duplicate Line');
      });

      test('moveLineUp creates action with correct ID', () {
        final action = DartEditorActions.moveLineUp();
        expect(action.id, DartEditorActions.moveLineUpActionId);
        expect(action.label, 'Move Line Up');
      });

      test('moveLineDown creates action with correct ID', () {
        final action = DartEditorActions.moveLineDown();
        expect(action.id, DartEditorActions.moveLineDownActionId);
        expect(action.label, 'Move Line Down');
      });

      test('factory methods accept custom handlers', () async {
        var triggered = false;
        final action = DartEditorActions.triggerCompletion(
          onTrigger: () {
            triggered = true;
            return true;
          },
        );
        await action.execute({});
        expect(triggered, true);
      });

      test('factory methods accept custom isEnabled', () {
        var enabled = false;
        final action = DartEditorActions.triggerCompletion(
          isEnabled: () => enabled,
        );
        expect(action.isEnabled(), false);
        enabled = true;
        expect(action.isEnabled(), true);
      });
    });

    group('defaultShortcuts', () {
      test('contains all 6 Dart-specific actions with shortcuts', () {
        final shortcuts = DartEditorActions.defaultShortcuts;
        expect(shortcuts.length, 6);
        expect(shortcuts.containsKey(DartEditorActions.triggerCompletionActionId),
            true);
        expect(
            shortcuts.containsKey(DartEditorActions.toggleCommentActionId), true);
        expect(
            shortcuts.containsKey(DartEditorActions.deleteLineActionId), true);
        expect(shortcuts.containsKey(DartEditorActions.duplicateLineActionId),
            true);
        expect(
            shortcuts.containsKey(DartEditorActions.moveLineUpActionId), true);
        expect(
            shortcuts.containsKey(DartEditorActions.moveLineDownActionId), true);
        // openReference has no default shortcut (Ctrl+R is reserved for shell)
        expect(
            shortcuts.containsKey(DartEditorActions.openReferenceActionId), false);
      });
    });

    group('alternativeShortcuts', () {
      test('only triggerCompletion has alternative shortcuts', () {
        final alts = DartEditorActions.alternativeShortcuts;
        expect(alts.length, 1);
        expect(
            alts.containsKey(DartEditorActions.triggerCompletionActionId), true);
      });

      test('triggerCompletion has 2 alternative shortcuts', () {
        final alts = DartEditorActions.alternativeShortcuts[
            DartEditorActions.triggerCompletionActionId]!;
        expect(alts.length, 2);
      });
    });
  });
}

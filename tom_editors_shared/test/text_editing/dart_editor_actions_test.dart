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
      });

      test('all action IDs start with dart. prefix', () {
        final ids = [
          DartEditorActions.triggerCompletionActionId,
          DartEditorActions.openReferenceActionId,
        ];
        for (final id in ids) {
          expect(id, startsWith('dart.'),
              reason: 'Action $id should start with dart.');
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
    });

    group('factory methods', () {
      test('triggerCompletion creates action with correct ID and shortcut', () {
        final action = DartEditorActions.triggerCompletion();
        expect(action.id, DartEditorActions.triggerCompletionActionId);
        expect(action.label, 'Trigger Completion');
        expect(action.defaultShortcut,
            DartEditorActions.triggerCompletionShortcut);
        expect(action.menu, ForgeMenuLocation.edit);
      });

      test('openReference creates action with correct ID and no shortcut', () {
        final action = DartEditorActions.openReference();
        expect(action.id, DartEditorActions.openReferenceActionId);
        expect(action.label, 'Open Reference');
        expect(action.defaultShortcut, isNull);
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
      test('contains only triggerCompletion', () {
        final shortcuts = DartEditorActions.defaultShortcuts;
        expect(shortcuts.length, 1);
        expect(
            shortcuts
                .containsKey(DartEditorActions.triggerCompletionActionId),
            true);
        // openReference has no default shortcut
        expect(
            shortcuts.containsKey(DartEditorActions.openReferenceActionId),
            false);
      });
    });

    group('alternativeShortcuts', () {
      test('only triggerCompletion has alternative shortcuts', () {
        final alts = DartEditorActions.alternativeShortcuts;
        expect(alts.length, 1);
        expect(
            alts.containsKey(DartEditorActions.triggerCompletionActionId),
            true);
      });

      test('triggerCompletion has 2 alternative shortcuts', () {
        final alts = DartEditorActions.alternativeShortcuts[
            DartEditorActions.triggerCompletionActionId]!;
        expect(alts.length, 2);
      });
    });

    group('descriptors', () {
      test('contains 2 descriptors', () {
        expect(DartEditorActions.descriptors, hasLength(2));
      });

      test('triggerCompletion descriptor', () {
        final desc = DartEditorActions.descriptors.firstWhere(
            (d) => d.id == DartEditorActions.triggerCompletionActionId);
        expect(desc.label, 'Trigger Completion');
        expect(desc.category, 'Dart Editor');
        expect(desc.suggestedShortcut,
            DartEditorActions.triggerCompletionShortcut);
      });

      test('openReference descriptor', () {
        final desc = DartEditorActions.descriptors.firstWhere(
            (d) => d.id == DartEditorActions.openReferenceActionId);
        expect(desc.label, 'Open Reference');
        expect(desc.category, 'Dart Editor');
      });
    });
  });
}

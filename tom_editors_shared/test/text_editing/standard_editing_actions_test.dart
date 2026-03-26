import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('StandardEditingActions', () {
    group('action IDs', () {
      test('has expected action IDs', () {
        expect(StandardEditingActions.cutActionId, 'forge.edit.cut');
        expect(StandardEditingActions.copyActionId, 'forge.edit.copy');
        expect(StandardEditingActions.pasteActionId, 'forge.edit.paste');
        expect(StandardEditingActions.selectAllActionId, 'forge.edit.selectAll');
        expect(StandardEditingActions.undoActionId, 'forge.edit.undo');
        expect(StandardEditingActions.redoActionId, 'forge.edit.redo');
      });
    });

    group('shortcuts', () {
      test('cut shortcut uses Cmd/Ctrl+X', () {
        final shortcut = StandardEditingActions.cutShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyX);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('copy shortcut uses Cmd/Ctrl+C', () {
        final shortcut = StandardEditingActions.copyShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyC);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('paste shortcut uses Cmd/Ctrl+V', () {
        final shortcut = StandardEditingActions.pasteShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyV);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('selectAll shortcut uses Cmd/Ctrl+A', () {
        final shortcut = StandardEditingActions.selectAllShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyA);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('undo shortcut uses Cmd/Ctrl+Z', () {
        final shortcut = StandardEditingActions.undoShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyZ);
        expect(shortcut.usePrimaryModifier, true);
        expect(shortcut.shift, false);
      });

      test('redo shortcut uses Cmd/Ctrl+Shift+Z', () {
        final shortcut = StandardEditingActions.redoShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyZ);
        expect(shortcut.usePrimaryModifier, true);
        expect(shortcut.shift, true);
      });

      test('redo alt shortcut uses Cmd/Ctrl+Y', () {
        final shortcut = StandardEditingActions.redoAltShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyY);
        expect(shortcut.usePrimaryModifier, true);
      });
    });

    group('action factories', () {
      test('cut creates action with correct id and label', () {
        final action = StandardEditingActions.cut();
        expect(action.id, StandardEditingActions.cutActionId);
        expect(action.label, 'Cut');
        expect(action.defaultShortcut, StandardEditingActions.cutShortcut);
        expect(action.menu, ForgeMenuLocation.edit);
      });

      test('copy creates action with correct id and label', () {
        final action = StandardEditingActions.copy();
        expect(action.id, StandardEditingActions.copyActionId);
        expect(action.label, 'Copy');
      });

      test('paste creates action with correct id and label', () {
        final action = StandardEditingActions.paste();
        expect(action.id, StandardEditingActions.pasteActionId);
        expect(action.label, 'Paste');
      });

      test('selectAll creates action with correct id and label', () {
        final action = StandardEditingActions.selectAll();
        expect(action.id, StandardEditingActions.selectAllActionId);
        expect(action.label, 'Select All');
      });

      test('undo creates action with correct id and label', () {
        final action = StandardEditingActions.undo();
        expect(action.id, StandardEditingActions.undoActionId);
        expect(action.label, 'Undo');
      });

      test('redo creates action with correct id and label', () {
        final action = StandardEditingActions.redo();
        expect(action.id, StandardEditingActions.redoActionId);
        expect(action.label, 'Redo');
      });
    });

    group('action callbacks', () {
      test('cut invokes callback via execute', () {
        bool called = false;
        final action = StandardEditingActions.cut(onCut: () {
          called = true;
          return true;
        });

        action.execute({});
        expect(called, true);
      });

      test('copy invokes callback via execute', () {
        bool called = false;
        final action = StandardEditingActions.copy(onCopy: () {
          called = true;
          return true;
        });

        action.execute({});
        expect(called, true);
      });

      test('paste invokes callback via execute', () {
        bool called = false;
        final action = StandardEditingActions.paste(onPaste: () {
          called = true;
          return true;
        });

        action.execute({});
        expect(called, true);
      });

      test('selectAll invokes callback via execute', () {
        bool called = false;
        final action = StandardEditingActions.selectAll(onSelectAll: () {
          called = true;
          return true;
        });

        action.execute({});
        expect(called, true);
      });

      test('undo invokes callback via execute', () {
        bool called = false;
        final action = StandardEditingActions.undo(onUndo: () {
          called = true;
          return true;
        });

        action.execute({});
        expect(called, true);
      });

      test('redo invokes callback via execute', () {
        bool called = false;
        final action = StandardEditingActions.redo(onRedo: () {
          called = true;
          return true;
        });

        action.execute({});
        expect(called, true);
      });
    });

    group('all', () {
      test('returns all six standard actions', () {
        final actions = StandardEditingActions.all();

        expect(actions.length, 6);
        expect(
          actions.map((a) => a.id),
          containsAll([
            StandardEditingActions.cutActionId,
            StandardEditingActions.copyActionId,
            StandardEditingActions.pasteActionId,
            StandardEditingActions.selectAllActionId,
            StandardEditingActions.undoActionId,
            StandardEditingActions.redoActionId,
          ]),
        );
      });

      test('all returns actions with callbacks', () {
        int callCount = 0;

        final actions = StandardEditingActions.all(
          onCut: () {
            callCount++;
            return true;
          },
          onCopy: () {
            callCount++;
            return true;
          },
          onPaste: () {
            callCount++;
            return true;
          },
          onSelectAll: () {
            callCount++;
            return true;
          },
          onUndo: () {
            callCount++;
            return true;
          },
          onRedo: () {
            callCount++;
            return true;
          },
        );

        for (final action in actions) {
          action.execute({});
        }

        expect(callCount, 6);
      });
    });

    group('defaultShortcuts', () {
      test('returns map of all shortcuts', () {
        final shortcuts = StandardEditingActions.defaultShortcuts;

        expect(shortcuts.length, 6);
        expect(
          shortcuts.containsKey(StandardEditingActions.cutActionId),
          true,
        );
        expect(
          shortcuts[StandardEditingActions.cutActionId],
          StandardEditingActions.cutShortcut,
        );
      });
    });
  });
}

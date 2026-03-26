import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('MdEditorActions', () {
    group('action IDs', () {
      test('has expected action IDs', () {
        expect(MdEditorActions.toggleBoldActionId, 'md.toggleBold');
        expect(MdEditorActions.toggleItalicActionId, 'md.toggleItalic');
        expect(MdEditorActions.toggleCodeActionId, 'md.toggleCode');
        expect(MdEditorActions.insertLinkActionId, 'md.insertLink');
        expect(MdEditorActions.insertTableActionId, 'md.insertTable');
        expect(MdEditorActions.insertHeadingActionId, 'md.insertHeading');
        expect(MdEditorActions.toggleListActionId, 'md.toggleList');
        expect(MdEditorActions.saveActionId, 'md.save');
        expect(MdEditorActions.searchActionId, 'md.search');
      });

      test('all action IDs start with md. prefix', () {
        final ids = [
          MdEditorActions.toggleBoldActionId,
          MdEditorActions.toggleItalicActionId,
          MdEditorActions.toggleCodeActionId,
          MdEditorActions.insertLinkActionId,
          MdEditorActions.insertTableActionId,
          MdEditorActions.insertHeadingActionId,
          MdEditorActions.toggleListActionId,
          MdEditorActions.saveActionId,
          MdEditorActions.searchActionId,
        ];
        for (final id in ids) {
          expect(id, startsWith('md.'), reason: 'Action $id should start with md.');
        }
      });
    });

    group('shortcuts', () {
      test('toggleBold uses primary+B', () {
        final shortcut = MdEditorActions.toggleBoldShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyB);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('toggleItalic uses primary+I', () {
        final shortcut = MdEditorActions.toggleItalicShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyI);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('toggleCode uses primary+E', () {
        final shortcut = MdEditorActions.toggleCodeShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyE);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('insertLink uses primary+K', () {
        final shortcut = MdEditorActions.insertLinkShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyK);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('insertTable uses Alt+T', () {
        final shortcut = MdEditorActions.insertTableShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyT);
        expect(shortcut.alt, true);
        expect(shortcut.usePrimaryModifier, false);
      });

      test('insertHeading uses Alt+H', () {
        final shortcut = MdEditorActions.insertHeadingShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyH);
        expect(shortcut.alt, true);
        expect(shortcut.usePrimaryModifier, false);
      });

      test('toggleList uses Alt+L', () {
        final shortcut = MdEditorActions.toggleListShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyL);
        expect(shortcut.alt, true);
        expect(shortcut.usePrimaryModifier, false);
      });

      test('save uses primary+S', () {
        final shortcut = MdEditorActions.saveShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyS);
        expect(shortcut.usePrimaryModifier, true);
      });

      test('search uses primary+F', () {
        final shortcut = MdEditorActions.searchShortcut;
        expect(shortcut.key, LogicalKeyboardKey.keyF);
        expect(shortcut.usePrimaryModifier, true);
      });
    });

    group('factory methods', () {
      test('toggleBold creates action with correct id and label', () {
        final action = MdEditorActions.toggleBold();
        expect(action.id, MdEditorActions.toggleBoldActionId);
        expect(action.label, 'Bold');
      });

      test('toggleItalic creates action with correct id and label', () {
        final action = MdEditorActions.toggleItalic();
        expect(action.id, MdEditorActions.toggleItalicActionId);
        expect(action.label, 'Italic');
      });

      test('toggleCode creates action with correct id and label', () {
        final action = MdEditorActions.toggleCode();
        expect(action.id, MdEditorActions.toggleCodeActionId);
        expect(action.label, 'Inline Code');
      });

      test('insertLink creates action with correct id and label', () {
        final action = MdEditorActions.insertLink();
        expect(action.id, MdEditorActions.insertLinkActionId);
        expect(action.label, 'Insert Link');
      });

      test('insertTable creates action with correct id and label', () {
        final action = MdEditorActions.insertTable();
        expect(action.id, MdEditorActions.insertTableActionId);
        expect(action.label, 'Insert Table');
      });

      test('insertHeading creates action with correct id and label', () {
        final action = MdEditorActions.insertHeading();
        expect(action.id, MdEditorActions.insertHeadingActionId);
        expect(action.label, 'Insert Heading');
      });

      test('toggleList creates action with correct id and label', () {
        final action = MdEditorActions.toggleList();
        expect(action.id, MdEditorActions.toggleListActionId);
        expect(action.label, 'Toggle List');
      });

      test('save creates action with correct id and label', () {
        final action = MdEditorActions.save();
        expect(action.id, MdEditorActions.saveActionId);
        expect(action.label, 'Save');
      });

      test('search creates action with correct id and label', () {
        final action = MdEditorActions.search();
        expect(action.id, MdEditorActions.searchActionId);
        expect(action.label, 'Find');
      });

      test('factory methods accept custom callbacks', () {
        var invoked = false;
        final action = MdEditorActions.toggleBold(
          onToggle: () {
            invoked = true;
            return true;
          },
          isEnabled: () => false,
        );
        expect(action.isEnabled(), false);
        action.execute({});
        expect(invoked, true);
      });

      test('insertTable defaults showInContextMenu to true', () {
        final action = MdEditorActions.insertTable();
        expect(action.showInContextMenu, true);
      });

      test('insertLink defaults showInContextMenu to true', () {
        final action = MdEditorActions.insertLink();
        expect(action.showInContextMenu, true);
      });

      test('toggleBold defaults showInContextMenu to false', () {
        final action = MdEditorActions.toggleBold();
        expect(action.showInContextMenu, false);
      });

      test('showInContextMenu can be overridden', () {
        final action = MdEditorActions.toggleBold(showInContextMenu: true);
        expect(action.showInContextMenu, true);
      });

      test('contextMenuActions returns only actions with showInContextMenu', () {
        final actions = MdEditorActions.contextMenuActions();
        expect(actions.length, greaterThanOrEqualTo(2));
        for (final action in actions) {
          expect(action.showInContextMenu, true,
              reason: '${action.id} should have showInContextMenu=true');
        }
        final ids = actions.map((a) => a.id).toSet();
        expect(ids, contains(MdEditorActions.insertTableActionId));
        expect(ids, contains(MdEditorActions.insertLinkActionId));
      });
    });

    group('shortcut maps', () {
      test('primaryShortcuts contains all action IDs', () {
        final map = MdEditorActions.primaryShortcuts;
        expect(map.length, 9);
        expect(map.containsKey(MdEditorActions.toggleBoldActionId), true);
        expect(map.containsKey(MdEditorActions.toggleItalicActionId), true);
        expect(map.containsKey(MdEditorActions.toggleCodeActionId), true);
        expect(map.containsKey(MdEditorActions.insertLinkActionId), true);
        expect(map.containsKey(MdEditorActions.insertTableActionId), true);
        expect(map.containsKey(MdEditorActions.insertHeadingActionId), true);
        expect(map.containsKey(MdEditorActions.toggleListActionId), true);
        expect(map.containsKey(MdEditorActions.saveActionId), true);
        expect(map.containsKey(MdEditorActions.searchActionId), true);
      });

      test('alternativeShortcuts is empty', () {
        expect(MdEditorActions.alternativeShortcuts, isEmpty);
      });
    });
  });
}

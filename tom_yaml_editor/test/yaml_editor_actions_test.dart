import 'package:flutter_test/flutter_test.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

void main() {
  group('YamlEditorActions', () {
    group('action IDs', () {
      test('has correct namespaced IDs', () {
        expect(YamlEditorActions.addKeyActionId, 'yaml.addKey');
        expect(YamlEditorActions.removeKeyActionId, 'yaml.removeKey');
        expect(YamlEditorActions.toggleTextModeActionId, 'yaml.toggleTextMode');
        expect(YamlEditorActions.saveActionId, 'yaml.save');
        expect(YamlEditorActions.searchActionId, 'yaml.search');
      });
    });

    group('shortcuts', () {
      test('addKey uses Ctrl+N', () {
        const shortcut = YamlEditorActions.addKeyShortcut;
        expect(shortcut.primaryModifier, isTrue);
        expect(shortcut.key.keyLabel, 'N');
      });

      test('removeKey uses Ctrl+Delete', () {
        const shortcut = YamlEditorActions.removeKeyShortcut;
        expect(shortcut.primaryModifier, isTrue);
      });

      test('toggleTextMode uses Ctrl+T', () {
        const shortcut = YamlEditorActions.toggleTextModeShortcut;
        expect(shortcut.primaryModifier, isTrue);
        expect(shortcut.key.keyLabel, 'T');
      });

      test('save uses Ctrl+S', () {
        const shortcut = YamlEditorActions.saveShortcut;
        expect(shortcut.primaryModifier, isTrue);
        expect(shortcut.key.keyLabel, 'S');
      });

      test('search uses Ctrl+F', () {
        const shortcut = YamlEditorActions.searchShortcut;
        expect(shortcut.primaryModifier, isTrue);
        expect(shortcut.key.keyLabel, 'F');
      });
    });

    group('factory methods', () {
      test('addKey defaults showInContextMenu to true', () {
        final action = YamlEditorActions.addKey();
        expect(action.id, YamlEditorActions.addKeyActionId);
        expect(action.showInContextMenu, isTrue);
        expect(action.label, 'Add Key');
      });

      test('removeKey defaults showInContextMenu to true', () {
        final action = YamlEditorActions.removeKey();
        expect(action.id, YamlEditorActions.removeKeyActionId);
        expect(action.showInContextMenu, isTrue);
        expect(action.label, 'Remove Key');
      });

      test('toggleTextMode defaults showInContextMenu to false', () {
        final action = YamlEditorActions.toggleTextMode();
        expect(action.id, YamlEditorActions.toggleTextModeActionId);
        expect(action.showInContextMenu, isFalse);
      });

      test('save defaults showInContextMenu to false', () {
        final action = YamlEditorActions.save();
        expect(action.id, YamlEditorActions.saveActionId);
        expect(action.showInContextMenu, isFalse);
      });

      test('search defaults showInContextMenu to false', () {
        final action = YamlEditorActions.search();
        expect(action.id, YamlEditorActions.searchActionId);
        expect(action.showInContextMenu, isFalse);
      });

      test('showInContextMenu can be overridden', () {
        final action =
            YamlEditorActions.toggleTextMode(showInContextMenu: true);
        expect(action.showInContextMenu, isTrue);
      });

      test('isEnabled defaults to returning true', () {
        final action = YamlEditorActions.addKey();
        expect(action.isEnabled(), isTrue);
      });

      test('isEnabled can be customized', () {
        final action = YamlEditorActions.addKey(isEnabled: () => false);
        expect(action.isEnabled(), isFalse);
      });
    });

    group('shortcut map', () {
      test('primaryShortcuts contains all action IDs', () {
        final map = YamlEditorActions.primaryShortcuts;
        expect(map.containsKey(YamlEditorActions.addKeyActionId), isTrue);
        expect(map.containsKey(YamlEditorActions.removeKeyActionId), isTrue);
        expect(
          map.containsKey(YamlEditorActions.toggleTextModeActionId),
          isTrue,
        );
        expect(map.containsKey(YamlEditorActions.saveActionId), isTrue);
        expect(map.containsKey(YamlEditorActions.searchActionId), isTrue);
        expect(map.length, 5);
      });
    });

    group('contextMenuActions', () {
      test('returns only actions with showInContextMenu true', () {
        final actions = YamlEditorActions.contextMenuActions();
        expect(actions.length, 2);
        expect(actions[0].id, YamlEditorActions.addKeyActionId);
        expect(actions[1].id, YamlEditorActions.removeKeyActionId);
        for (final action in actions) {
          expect(action.showInContextMenu, isTrue);
        }
      });
    });
  });
}

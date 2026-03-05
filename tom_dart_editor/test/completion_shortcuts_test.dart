import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/src/completion_shortcuts.dart';

void main() {
  group('CompletionShortcutResolver', () {
    test('ctrl+space triggers completion when enabled', () {
      final action = CompletionShortcutResolver.resolve(
        autoCompleteEnabled: true,
        isControlPressed: true,
        isMetaPressed: false,
        isAltPressed: false,
        isShiftPressed: false,
        isSpace: true,
        isKeyI: false,
        isKeyR: false,
        isKeyZ: false,
        isKeyY: false,
      );

      expect(action, CompletionShortcutAction.triggerCompletion);
    });

    test('alt+space triggers completion when enabled', () {
      final action = CompletionShortcutResolver.resolve(
        autoCompleteEnabled: true,
        isControlPressed: false,
        isMetaPressed: false,
        isAltPressed: true,
        isShiftPressed: false,
        isSpace: true,
        isKeyI: false,
        isKeyR: false,
        isKeyZ: false,
        isKeyY: false,
      );

      expect(action, CompletionShortcutAction.triggerCompletion);
    });

    test('ctrl+space does not trigger when autocomplete disabled', () {
      final action = CompletionShortcutResolver.resolve(
        autoCompleteEnabled: false,
        isControlPressed: true,
        isMetaPressed: false,
        isAltPressed: false,
        isShiftPressed: false,
        isSpace: true,
        isKeyI: false,
        isKeyR: false,
        isKeyZ: false,
        isKeyY: false,
      );

      expect(action, CompletionShortcutAction.none);
    });

    test('ctrl+r opens reference', () {
      final action = CompletionShortcutResolver.resolve(
        autoCompleteEnabled: true,
        isControlPressed: true,
        isMetaPressed: false,
        isAltPressed: false,
        isShiftPressed: false,
        isSpace: false,
        isKeyI: false,
        isKeyR: true,
        isKeyZ: false,
        isKeyY: false,
      );

      expect(action, CompletionShortcutAction.openReference);
    });

    test('undo and redo shortcuts are resolved', () {
      final undoAction = CompletionShortcutResolver.resolve(
        autoCompleteEnabled: true,
        isControlPressed: true,
        isMetaPressed: false,
        isAltPressed: false,
        isShiftPressed: false,
        isSpace: false,
        isKeyI: false,
        isKeyR: false,
        isKeyZ: true,
        isKeyY: false,
      );

      final redoAction = CompletionShortcutResolver.resolve(
        autoCompleteEnabled: true,
        isControlPressed: true,
        isMetaPressed: false,
        isAltPressed: false,
        isShiftPressed: false,
        isSpace: false,
        isKeyI: false,
        isKeyR: false,
        isKeyZ: false,
        isKeyY: true,
      );

      expect(undoAction, CompletionShortcutAction.undo);
      expect(redoAction, CompletionShortcutAction.redo);
    });
  });
}

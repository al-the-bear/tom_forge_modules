/// The helpers every Forge editor keeps its history with (wonecmpc19):
/// [ForgeTextHistory] (grouped typing, selection before and after, flushed at
/// every boundary, no entry for no change), [ForgeSavedMarker] (dirty against
/// the saved state) and [ForgeEditorOwnsUndo] (Flutter's own text-field undo
/// off).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

ForgeTextState _at(String text, int caret) =>
    ForgeTextState(text, TextSelection.collapsed(offset: caret));

void main() {
  group('HIST ForgeTextHistory', () {
    testWidgets('HIST-1: typing without a pause is one entry; a pause ends '
        'it', (tester) async {
      final h = ForgeTextHistory(_at('', 0));
      addTearDown(h.dispose);
      h.edited(_at('h', 1));
      h.edited(_at('he', 2));
      h.edited(_at('hey', 3));
      expect(h.entries, isEmpty, reason: 'still pending');
      expect(h.canUndo, isTrue, reason: 'pending typing is undoable');
      await tester.pump(forgeTypingPause);
      expect(h.entries, hasLength(1));
      h.edited(_at('hey!', 4));
      await tester.pump(forgeTypingPause);
      expect(h.entries.map((e) => e.newText), ['hey', 'hey!']);
    });

    testWidgets('HIST-2: undo within the pause takes back the typing; the '
        'caret returns to where it was before', (tester) async {
      final h = ForgeTextHistory(_at('ab', 1));
      addTearDown(h.dispose);
      h.edited(_at('aXb', 2));
      ForgeTextState? applied;
      expect(h.undo((s) => applied = s), isTrue);
      expect(applied, _at('ab', 1));
      expect(h.current, _at('ab', 1));
      expect(h.redo((s) => applied = s), isTrue);
      expect(applied, _at('aXb', 2), reason: 'redo restores the after-caret');
    });

    test('HIST-3: a caret move ends the gesture; typing back to where it '
        'started makes no entry', () {
      final h = ForgeTextHistory(_at('abc', 3));
      addTearDown(h.dispose);
      h.edited(_at('abcd', 4));
      h.selected(const TextSelection.collapsed(offset: 0));
      expect(h.entries, hasLength(1));
      h.edited(_at('Xabcd', 1));
      h.edited(_at('abcd', 0));
      h.flush();
      expect(h.entries, hasLength(1), reason: 'no change, no entry');
      h.edited(_at('abcd', 0));
      expect(h.hasPendingTyping, isFalse, reason: 'same text is a caret move');
    });

    test('HIST-4: the edit an undo applies is not recorded; typing after an '
        'undo ends the redo future', () {
      final h = ForgeTextHistory(_at('', 0));
      addTearDown(h.dispose);
      h
        ..edited(_at('a', 1))
        ..flush();
      h.undo((s) => h.edited(s)); // the editor's own listener reporting back
      expect(h.canRedo, isTrue);
      expect(h.entries, isEmpty);
      h.edited(_at('b', 1));
      expect(h.canRedo, isFalse);
      expect(h.redo((_) {}), isFalse);
    });

    test('HIST-5: an application that throws leaves the entry undoable', () {
      final h = ForgeTextHistory(_at('', 0));
      addTearDown(h.dispose);
      h
        ..edited(_at('a', 1))
        ..flush();
      expect(() => h.undo((_) => throw StateError('no')), throwsStateError);
      expect(h.entries, hasLength(1));
    });

    test('HIST-6: replace clears the history and pending typing; the depth '
        'can change on an open history', () {
      final h = ForgeTextHistory(_at('', 0), maxEntries: 3);
      addTearDown(h.dispose);
      for (final t in ['a', 'ab', 'abc', 'abcd']) {
        h
          ..edited(ForgeTextState.atEnd(t))
          ..flush();
      }
      expect(h.entries, hasLength(3));
      h.maxEntries = 1;
      expect(h.entries.single.newText, 'abcd');
      h.edited(ForgeTextState.atEnd('abcde'));
      h.replace(ForgeTextState.atEnd('from disk'));
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
      expect(h.current.text, 'from disk');
    });
  });

  group('MARK ForgeSavedMarker', () {
    test('MARK-1: dirty follows the saved state, not the history', () {
      final marker = ForgeSavedMarker('saved');
      addTearDown(marker.dispose);
      marker.compare('edited');
      expect(marker.isDirty.value, isTrue);
      marker.compare('saved');
      expect(marker.isDirty.value, isFalse, reason: 'undo back to saved');
      marker.markSaved('edited');
      marker.compare('saved');
      expect(marker.isDirty.value, isTrue, reason: 'undo past the save');
    });
  });

  group('OWNS ForgeEditorOwnsUndo', () {
    testWidgets('OWNS-1: the platform undo key does nothing in a text field '
        'below it; without it, the field undoes its own typing', (
      tester,
    ) async {
      Future<String> typeThenUndo({required bool owned}) async {
        final controller = TextEditingController();
        final field = TextField(controller: controller, autofocus: true);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: owned ? ForgeEditorOwnsUndo(child: field) : field,
            ),
          ),
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'first');
        await tester.pump(const Duration(seconds: 1));
        await tester.enterText(find.byType(TextField), 'first second');
        await tester.pump(const Duration(seconds: 1));
        final mac = defaultTargetPlatform == TargetPlatform.macOS;
        final modifier = mac
            ? LogicalKeyboardKey.metaLeft
            : LogicalKeyboardKey.controlLeft;
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
        return controller.text;
      }

      expect(await typeThenUndo(owned: false), 'first');
      expect(await typeThenUndo(owned: true), 'first second');
    });
  });
}

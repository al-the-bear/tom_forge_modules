/// The Markdown editor's one history (wonecmpc22): no entry for a change
/// that changed nothing, content from outside and a load are not undoable and
/// are the saved state, section mode keeps its section across an undone
/// rename, an asynchronous section update does not wipe the typing that
/// follows it, and the search field's undo keys stay out of the document.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

const _doc = '# One\n\nfirst\n\n# Two\n\nsecond\n';

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

Widget _editor(MdEditorController controller) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 1000,
      height: 800,
      child: MdEditor(
        controller: controller,
        settings: const MdEditorSettings(showTree: false, autoHideEditor: false),
      ),
    ),
  ),
);

void main() {
  group('MH the controller', () {
    test('MH-1: an edit that changes nothing is no entry; content from '
        'outside is saved and not undoable', () {
      final c = MdEditorController(initialMarkdown: _doc);
      addTearDown(c.dispose);
      c.applyEdit(_doc);
      expect(c.canUndo, isFalse);
      c.applyEdit('changed');
      expect(c.isDirty.value, isTrue);
      c.replaceContent('from disk');
      expect(c.canUndo, isFalse);
      expect(c.isDirty.value, isFalse);
    });

    test('MH-2: a load resets the history and is the saved state', () async {
      final c = MdEditorController(initialMarkdown: 'old');
      addTearDown(c.dispose);
      c.applyEdit('edited');
      await c.loadFromProvider(StringDocumentProvider(markdown: 'loaded'));
      expect(c.markdown, 'loaded');
      expect(c.canUndo, isFalse);
      expect(c.isDirty.value, isFalse);
    });

    test('MH-3: undoing a rename keeps the renamed section selected', () async {
      final c = MdEditorController(initialMarkdown: _doc);
      addTearDown(c.dispose);
      final two = c.document.allSections.firstWhere((s) => s.headline == 'Two');
      c.selectSection(two);
      await c.updateSectionHeadline(two, 'Second');
      expect(c.selectedSection?.headline, 'Second');
      c.undo();
      expect(c.markdown, _doc);
      expect(c.selectedSection?.headline, 'Two');
      c.redo();
      expect(c.selectedSection?.headline, 'Second');
    });

    test('MH-4: a toolbar change of a section is its own entry; typing in a '
        'section is one entry per gesture', () async {
      final c = MdEditorController(initialMarkdown: _doc);
      addTearDown(c.dispose);
      MdSection one() => c.document.allSections.first;
      await c.updateSectionText(one(), 'first a', typing: true);
      await c.updateSectionText(one(), 'first ab', typing: true);
      await c.updateSectionText(one(), 'first ab\n\n---');
      c.undo();
      expect(one().text.trim(), 'first ab');
      c.undo();
      expect(c.markdown, _doc);
    });
  });

  group('MH the raw editor', () {
    testWidgets('MH-5: an asynchronous section update does not wipe typing '
        'made while it runs', (tester) async {
      final gate = Completer<void>();
      final c = MdEditorController(
        initialMarkdown: _doc,
        eventHandlers: MdEditorEventHandlers(
          onBeforeTextChange: (event) async {
            await gate.future;
            return event;
          },
        ),
      );
      addTearDown(c.dispose);
      c.selectSection(c.document.allSections.first);
      await tester.pumpWidget(_editor(c));
      await tester.pumpAndSettle();
      final raw = find
          .descendant(
            of: find.byType(MdRawTextEditor),
            matching: find.byType(EditableText),
          )
          .first;
      TextEditingController field() =>
          tester.widget<EditableText>(raw).controller;
      await tester.showKeyboard(raw);
      final start = field().text;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '${start}X',
          selection: TextSelection.collapsed(offset: start.length + 1),
        ),
      );
      await tester.pump(const Duration(seconds: 1)); // the debounce fires
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '${start}XY',
          selection: TextSelection.collapsed(offset: start.length + 2),
        ),
      );
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(field().text, '${start}XY', reason: 'the typing survives');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('MH-6: the undo key in the search field undoes the field, '
        'not the document', (tester) async {
      final c = MdEditorController(initialMarkdown: _doc);
      addTearDown(c.dispose);
      await tester.pumpWidget(_editor(c));
      await tester.pumpAndSettle();
      await tester.showKeyboard(
        find
            .descendant(
              of: find.byType(MdRawTextEditor),
              matching: find.byType(EditableText),
            )
            .first,
      );
      await _press(tester, LogicalKeyboardKey.keyF);
      final search = find
          .descendant(
            of: find.byType(MdSearchPanel),
            matching: find.byType(EditableText),
          )
          .first;
      await tester.showKeyboard(search);
      await tester.enterText(search, 'fir');
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(search, 'first');
      await tester.pump(const Duration(seconds: 1));
      await _press(tester, LogicalKeyboardKey.keyZ);
      expect(tester.widget<EditableText>(search).controller.text, 'fir');
      expect(c.markdown, _doc);
      expect(c.canUndo, isFalse);
    });
  });
}

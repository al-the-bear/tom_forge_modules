/// The Dart editor's one history (wonecmpc21): words are entries, redo after
/// typing is gone, dirty follows the saved code, split views share the
/// history — and the external history mode, where a host keeps the history
/// and the editor only reports to it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

/// A host keeping the history of one Dart field the way a document editor
/// would: its own stack of texts.
class _Host implements DartCodeHistoryHost {
  final reported = <String>[];
  final stack = <String>[];
  final undone = <String>[];
  var flushes = 0;
  final _changed = ChangeNotifier();
  late DartCodeController controller;

  @override
  void edited(String code, TextSelection selection) {
    reported.add(code);
    stack.add(code);
    undone.clear();
    _changed.notifyListeners();
  }

  @override
  void flush() => flushes++;

  @override
  bool get canUndo => stack.isNotEmpty;

  @override
  bool get canRedo => undone.isNotEmpty;

  @override
  void undo() {
    undone.add(stack.removeLast());
    controller.showCode(stack.isEmpty ? '' : stack.last);
    _changed.notifyListeners();
  }

  @override
  void redo() {
    final code = undone.removeLast();
    stack.add(code);
    controller.showCode(code);
    _changed.notifyListeners();
  }

  @override
  Listenable get changed => _changed;
}

TextSelection _at(int offset) => TextSelection.collapsed(offset: offset);

void main() {
  group('DH the controller\'s history', () {
    testWidgets('DH-1: a typed word separator ends the word\'s entry', (
      tester,
    ) async {
      final c = DartCodeController();
      addTearDown(c.dispose);
      for (final t in ['f', 'fo', 'foo', 'foo ', 'foo b', 'foo ba']) {
        c.edit(t, _at(t.length));
      }
      c.undo();
      expect(c.userCode, 'foo ');
      c.undo();
      expect(c.userCode, '');
      expect(c.selection, _at(0));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('DH-2: redo right after an undo within the pause restores '
        'the typing; typing after an undo ends the redo', (tester) async {
      final c = DartCodeController(initialCode: 'a');
      addTearDown(c.dispose);
      c.edit('ab', _at(2));
      c.undo();
      expect(c.userCode, 'a');
      c.redo();
      expect(c.userCode, 'ab');
      expect(c.selection, _at(2));
      c.undo();
      c.edit('ac', _at(2));
      expect(c.canRedo, isFalse);
      await tester.pump(const Duration(seconds: 2));
    });

    test('DH-3: dirty is measured against the saved code', () {
      final c = DartCodeController(initialCode: 'x');
      addTearDown(c.dispose);
      c.applyEdit('y');
      expect(c.isDirty.value, isTrue);
      c.undo();
      expect(c.isDirty.value, isFalse);
      c.redo();
      c.markSaved();
      c.undo();
      expect(c.isDirty.value, isTrue);
    });

    testWidgets('DH-4: two views of one controller share the code and the '
        'history', (tester) async {
      final c = DartCodeController(initialCode: 'one');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(child: DartCodeEditor(controller: c)),
                Expanded(child: DartCodeEditor(controller: c)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(EditableText);
      await tester.enterText(fields.first, 'one two');
      await tester.pump(const Duration(seconds: 2));
      String textOf(int i) =>
          tester.widget<EditableText>(fields.at(i)).controller.text;
      expect(textOf(1), 'one two');
      c.undo();
      await tester.pumpAndSettle();
      expect(textOf(0), 'one');
      expect(textOf(1), 'one');
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('DX the external history mode', () {
    testWidgets('DX-1: the editor reports typing and flushes to the host, '
        'keeps no history, and takes undo and redo from it', (tester) async {
      final host = _Host();
      final c = DartCodeController(initialCode: '', historyHost: host);
      host.controller = c;
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DartCodeEditor(controller: c))),
      );
      await tester.pumpAndSettle();
      final field = find.byType(EditableText).first;
      await tester.enterText(field, 'a');
      await tester.enterText(field, 'a;');
      expect(host.reported, ['a', 'a;']);
      expect(host.flushes, greaterThan(0), reason: 'the ; ended the word');
      expect(c.canUndo, isTrue);

      c.undo();
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).controller.text, 'a');
      expect(host.reported, ['a', 'a;'], reason: 'shown text is no edit');
      c.redo();
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).controller.text, 'a;');
    });

    test('DX-2: a programmatic edit is reported between two flushes; '
        'replaceCode leaves the host\'s history to the host', () {
      final host = _Host();
      final c = DartCodeController(initialCode: 'x', historyHost: host);
      host.controller = c;
      addTearDown(c.dispose);
      c.applyEdit('xy');
      expect(host.reported, ['xy']);
      expect(host.flushes, 2);
      c.replaceCode('fresh');
      expect(c.userCode, 'fresh');
      expect(c.isDirty.value, isFalse);
      expect(host.stack, ['xy'], reason: 'the host clears its own history');
    });
  });

  group('DS the self-managed editor as a document field', () {
    testWidgets('DS-1: with a history host, a new initialCode (the document '
        'undone) is shown, and the field\'s typing goes to the host', (
      tester,
    ) async {
      final host = _Host();
      Widget field(String code) => MaterialApp(
        home: Scaffold(
          body: SimpleSummaryBackedDartCodeEditor(
            initialCode: code,
            scope: 'does-not-exist',
            settings: const DartEditorSettings(showToolbar: false),
            historyHost: host,
          ),
        ),
      );
      await tester.pumpWidget(field('a'));
      final editable = find.byType(EditableText).first;
      final controller = tester.widget<EditableText>(editable).controller;
      controller.value = const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      expect(host.reported.last, 'ab');
      await tester.pumpWidget(field('ab')); // the document took the typing
      expect(tester.widget<EditableText>(editable).controller.text, 'ab');

      await tester.pumpWidget(field('a')); // the document went back
      await tester.pump();
      expect(tester.widget<EditableText>(editable).controller.text, 'a');
      expect(host.reported, ['ab'], reason: 'showing is not an edit');
      await tester.pump(const Duration(seconds: 2));
    });
  });
}

/// The self-managed summary-backed editor as a field of a larger document
/// (wonecmpc21): with a history host, a new initial code is shown and the
/// field's typing goes to the host. The editor's own history is
/// `tom_dart_editor`'s `wonecmpc21_history_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_analysis/tom_dart_analysis.dart';
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

void main() {
  group('DS the self-managed editor as a document field', () {
    testWidgets(
        'DS-1: with a history host, a new initialCode (the document '
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

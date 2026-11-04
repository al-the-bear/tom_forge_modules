/// The Markdown editor's undo as a user met it (wonecmpc22), driven only
/// through the raw editor's field and the undo key: undo puts the cursor
/// where it was before the edit, not on the next line, and a word typed just
/// before the undo is what the undo takes back — nothing older, and nothing
/// lost.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

Future<MdEditorController> _mount(WidgetTester tester, String markdown) async {
  final controller = MdEditorController(initialMarkdown: markdown);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 800,
          child: MdEditor(
            controller: controller,
            settings: const MdEditorSettings(
              showTree: false,
              autoHideEditor: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Finder get _raw => find
    .descendant(
      of: find.byType(MdRawTextEditor),
      matching: find.byType(EditableText),
    )
    .first;

TextEditingController _field(WidgetTester tester) =>
    tester.widget<EditableText>(_raw).controller;

/// Types: the field's value becomes [value], as an input method sets it.
Future<void> _type(WidgetTester tester, TextEditingValue value) async {
  tester.testTextInput.updateEditingValue(value);
  await tester.pump();
}

Future<void> _undoKey(WidgetTester tester) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MR-1: undo puts the cursor where it was before the edit, not '
      'on the next line', (tester) async {
    await _mount(tester, 'a\nb');
    await tester.showKeyboard(_raw);
    _field(tester).selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    await _type(
      tester,
      const TextEditingValue(
        text: 'aX\nb',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await _undoKey(tester);
    expect(_field(tester).text, 'a\nb');
    expect(_field(tester).selection.baseOffset, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('MR-2: a word typed just before the undo is what the undo '
      'takes back; the earlier text stays', (tester) async {
    await _mount(tester, '');
    await tester.showKeyboard(_raw);
    await _type(
      tester,
      const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await _type(
      tester,
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    await _undoKey(tester);
    expect(_field(tester).text, 'hello');
    await tester.pump(const Duration(seconds: 2));
    expect(_field(tester).text, 'hello', reason: 'nothing arrives late');
  });
}

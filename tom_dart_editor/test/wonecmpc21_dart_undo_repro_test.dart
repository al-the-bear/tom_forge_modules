/// The Dart editor's undo as a user met it (wonecmpc21), driven only through
/// the text field and the keyboard: a word typed at an ordinary pace is
/// undone as a whole, not half of it, and undo puts the caret back where it
/// was before the edit, not on the first line.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

Future<void> _mount(WidgetTester tester, DartCodeController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: DartCodeEditor(controller: controller),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TextEditingController _field(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first).controller;

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
  testWidgets('DR-1: a word typed at an ordinary pace is undone whole', (
    tester,
  ) async {
    final controller = DartCodeController(initialCode: 'var ');
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    await tester.tap(find.byType(EditableText).first);
    var text = 'var ';
    for (final char in 'hello'.split('')) {
      text += char;
      await tester.enterText(find.byType(EditableText).first, text);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 2));
    await _undoKey(tester);
    expect(_field(tester).text, 'var ', reason: 'not half of the word');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('DR-2: undo puts the caret where it was before the edit, not '
      'on the first line', (tester) async {
    final controller = DartCodeController(initialCode: 'line1\nline2');
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    await tester.tap(find.byType(EditableText).first);
    await tester.enterText(find.byType(EditableText).first, 'line1\nline2x');
    await tester.pump(const Duration(seconds: 2));
    await _undoKey(tester);
    expect(_field(tester).text, 'line1\nline2');
    expect(_field(tester).selection.baseOffset, 11);
    await tester.pump(const Duration(seconds: 2));
  });
}

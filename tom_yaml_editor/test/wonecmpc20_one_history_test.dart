/// The YAML editor keeps one history per document (wonecmpc20): every view
/// shares one mode, switching modes keeps the history, the undo key in a tree
/// field reaches the document's history, an embedded editor's edits are the
/// document's, and a structural edit that changes nothing is no entry.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

Widget _views(YamlEditorController controller,
        {int count = 1, EditorRegistry? registry}) =>
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: YamlSchemaEditor(
                  key: ValueKey('view$i'),
                  controller: controller,
                  editorRegistry: registry,
                ),
              ),
          ],
        ),
      ),
    );

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key,
    {bool shift = false}) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => kYamlEditorDebug = false);

  testWidgets('OH-1: two views of one document share its mode', (tester) async {
    final controller = YamlEditorController(initialYaml: 'name: a\n');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_views(controller, count: 2));
    await tester.pumpAndSettle();
    expect(find.byType(StringEditor), findsNWidgets(2));

    controller.textMode = true;
    await tester.pumpAndSettle();
    expect(find.byType(StringEditor), findsNothing, reason: 'both in source');
  });

  testWidgets(
      'OH-2: an edit made in the tree is undone in source mode; '
      'switching modes adds no entry', (tester) async {
    final controller = YamlEditorController(initialYaml: 'name: a\n');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_views(controller));
    await tester.pumpAndSettle();
    controller.setValue(['name'], 'b');
    controller.textMode = true;
    controller.textMode = false;
    controller.textMode = true;
    await tester.pumpAndSettle();
    controller.undo();
    expect(controller.sourceText, 'name: a\n');
    expect(controller.canUndo, isFalse, reason: 'one entry, the edit');
    expect(controller.isDirty.value, isFalse);
  });

  testWidgets(
      'OH-3: the undo and redo keys pressed in a tree field undo and '
      'redo the document', (tester) async {
    final controller = YamlEditorController(initialYaml: 'name: a\n');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_views(controller));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(StringEditor),
      matching: find.byType(EditableText),
    );
    await tester.tap(field);
    await tester.enterText(field, 'ab');
    await tester.pump(const Duration(seconds: 2));
    await _press(tester, LogicalKeyboardKey.keyZ);
    expect(controller.sourceText, 'name: a\n');
    expect(tester.widget<EditableText>(field).controller.text, 'a');
    await _press(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(controller.sourceText, 'name: ab\n');
  });

  testWidgets(
      'OH-4: an embedded editor registered by key suffix edits '
      'through the document\'s history', (tester) async {
    final controller = YamlEditorController(initialYaml: 'note-shout: a\n');
    addTearDown(controller.dispose);
    final registry = EditorRegistry.defaults().register(
      EditorSuffix(
        suffix: 'shout',
        label: 'Shout',
        factory: ({
          required key,
          required value,
          required onChanged,
          required theme,
          required readOnly,
        }) =>
            TextButton(
          onPressed: () => onChanged('${value ?? ''}!'),
          child: Text('shout ${value ?? ''}'),
        ),
      ),
    );
    await tester.pumpWidget(_views(controller, registry: registry));
    await tester.pumpAndSettle();
    await tester.tap(find.text('shout a'));
    await tester.pump(const Duration(seconds: 2));
    expect(controller.sourceText, 'note-shout: a!\n');
    controller.undo();
    await tester.pumpAndSettle();
    expect(controller.sourceText, 'note-shout: a\n');
    expect(find.text('shout a'), findsOneWidget);
  });

  test(
      'OH-5: an edit that changes nothing is no entry; a refused edit '
      'changes nothing', () {
    final controller = YamlEditorController(initialYaml: 'name: a\n');
    addTearDown(controller.dispose);
    controller.setValue(['name'], 'a');
    expect(controller.canUndo, isFalse);
    controller.moveListItem(['name'], 0, 0);
    expect(controller.canUndo, isFalse);
    expect(controller.isDirty.value, isFalse);
  });

  test(
      'OH-6: saving moves the saved marker; undo past it is dirty, back at it '
      'clean', () {
    final controller = YamlEditorController(initialYaml: 'n: 1\n');
    addTearDown(controller.dispose);
    controller.setValue(['n'], 2);
    controller.markClean();
    expect(controller.isDirty.value, isFalse);
    controller.undo();
    expect(controller.isDirty.value, isTrue);
    controller.redo();
    expect(controller.isDirty.value, isFalse);
  });

  testWidgets('OH-7: typing in source mode is one entry per gesture', (
    tester,
  ) async {
    final controller = YamlEditorController(initialYaml: 'a: 1\n');
    addTearDown(controller.dispose);
    for (final text in ['a: 1\nb', 'a: 1\nb:', 'a: 1\nb: 2']) {
      controller.editSource(text, TextSelection.collapsed(offset: text.length));
    }
    controller.undo();
    expect(controller.sourceText, 'a: 1\n');
    expect(controller.canUndo, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('OH-8: an emptied number field writes no null while typing, '
      'and null once focus leaves it empty', (tester) async {
    final controller = YamlEditorController(initialYaml: 'n: 5\n');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_views(controller));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(IntegerEditor),
      matching: find.byType(EditableText),
    );
    await tester.tap(field);
    await tester.enterText(field, '');
    await tester.pump();
    expect(controller.sourceText, 'n: 5\n', reason: 'no intermediate null');
    await tester.enterText(field, '6');
    await tester.pump();
    expect(controller.sourceText, 'n: 6\n');
    await tester.enterText(field, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(controller.document.nodeAt(const ['n'])?.value, isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}

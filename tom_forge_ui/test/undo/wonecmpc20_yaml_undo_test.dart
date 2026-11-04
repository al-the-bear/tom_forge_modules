/// The YAML editor's undo, as a user meets it (wonecmpc20): an edit in a
/// tree-mode field is undone by the shell's Undo, the document is clean again
/// at the saved state, and a source draft that does not parse survives an
/// undo and comes back with redo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions, forgeTypingPause;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart'
    show StringEditor, YamlEditorController, kYamlEditorDebug;

ForgeYamlEditor _editor(String yaml) {
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: const {},
    appName: 'YAML undo',
    navigatorKey: GlobalKey<NavigatorState>(),
  );
  return ForgeYamlEditor(
    controller: YamlEditorController(initialYaml: yaml),
    module: TomForgeShellModule()..activate(shell),
  );
}

Future<void> _mount(WidgetTester tester, ForgeYamlEditor editor) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 700,
          child: Builder(builder: editor.buildMain),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

void main() {
  // The YAML editor's debug trail replaces FlutterError.onError, which a
  // failing widget test cannot survive.
  setUp(() => kYamlEditorDebug = false);

  testWidgets('YU-1: a tree-mode field edit is undone by the shell\'s Undo '
      'and the document is clean again', (tester) async {
    final editor = _editor('name: old\n');
    await _mount(tester, editor);
    final field = find.descendant(
      of: find.byType(StringEditor),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'new');
    await tester.pump(forgeTypingPause);
    expect(editor.controller.yamlText, 'name: new\n');
    expect(editor.isDirty.value, isTrue);

    expect(editor.isActionEnabled(_undo), isTrue, reason: 'undo is offered');
    expect(editor.executeAction(_undo), isTrue);
    await tester.pumpAndSettle();
    expect(editor.controller.yamlText, 'name: old\n');
    expect(editor.isDirty.value, isFalse, reason: 'back at the saved state');
    expect(tester.widget<EditableText>(field).controller.text, 'old');

    expect(editor.executeAction(_redo), isTrue);
    await tester.pumpAndSettle();
    expect(editor.controller.yamlText, 'name: new\n');
    await tester.pump(forgeTypingPause);
  });

  testWidgets('YU-2: typing a word into a field is one undo step, and an '
      'emptied number field writes no null while typing', (tester) async {
    final editor = _editor('name: a\n');
    await _mount(tester, editor);
    final field = find.descendant(
      of: find.byType(StringEditor),
      matching: find.byType(EditableText),
    );
    for (final text in ['ab', 'abc', 'abcd']) {
      await tester.enterText(field, text);
      await tester.pump();
    }
    await tester.pump(forgeTypingPause);
    editor.executeAction(_undo);
    await tester.pumpAndSettle();
    expect(editor.controller.yamlText, 'name: a\n');
    expect(editor.isActionEnabled(_undo), isFalse, reason: 'one step only');
  });

  testWidgets('YU-3: a source draft that does not parse is kept by undo '
      'and comes back with redo', (tester) async {
    final editor = _editor('name: old\n');
    editor.controller.textMode = true;
    await _mount(tester, editor);
    final source = find.byType(EditableText).first;
    await tester.enterText(source, 'name: old\nbroken: [\n');
    await tester.pump(forgeTypingPause);
    expect(editor.controller.parseError, isNotNull);
    expect(editor.getContent(), 'name: old\nbroken: [\n');

    editor.executeAction(_undo);
    await tester.pumpAndSettle();
    expect(editor.getContent(), 'name: old\n');
    expect(editor.isDirty.value, isFalse);
    editor.executeAction(_redo);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(source).controller.text,
      'name: old\nbroken: [\n',
      reason: 'the draft is recoverable',
    );
    await tester.pump(forgeTypingPause);
  });
}

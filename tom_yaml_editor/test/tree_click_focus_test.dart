/// A click in the YAML editor's tree: into an inline value editor it focuses
/// the editor's text field, not the tree; on a row's key label it gives the
/// tree the keyboard, so the arrows move the tree's focus at once.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

void main() {
  setUp(() => kYamlEditorDebug = false);

  testWidgets(
      'YTF-1: a click into an inline editor keeps its text field '
      'focused; a click on a key label gives the tree the keyboard', (
    tester,
  ) async {
    final controller = YamlEditorController(initialYaml: 'name: a\ncount: b\n');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: YamlSchemaEditor(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final tree = tester
        .widget<TreeView<YamlTreeData>>(find.byType(TreeView<YamlTreeData>))
        .controller;
    final treeFocus = tester
        .widget<KeyboardListener>(
          find.descendant(
            of: find.byType(TreeView<YamlTreeData>),
            matching: find.byType(KeyboardListener),
          ),
        )
        .focusNode;
    final fields = find.descendant(
      of: find.byType(StringEditor),
      matching: find.byType(EditableText),
    );
    expect(fields, findsNWidgets(2));

    // Into the second row's value editor: its text field has the keyboard.
    await tester.tap(fields.last);
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(fields.last).focusNode;
    expect(field.hasPrimaryFocus, isTrue);
    expect(treeFocus.hasPrimaryFocus, isFalse);
    await tester.enterText(fields.last, 'bc');
    await tester.pumpAndSettle();
    expect(field.hasPrimaryFocus, isTrue);

    // On the second row's key label: the tree takes the keyboard.
    await tester.tap(find.textContaining('count', findRichText: true).first);
    await tester.pumpAndSettle();
    expect(treeFocus.hasPrimaryFocus, isTrue);
    expect(field.hasFocus, isFalse);
    final focusedBefore = tree.focusedId;
    expect(focusedBefore, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tree.focusedId, isNot(focusedBefore));
    expect(tree.focusedId, tree.visibleNodes.first.id);
  });
}

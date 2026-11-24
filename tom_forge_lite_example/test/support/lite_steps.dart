// The steps the widget test and the macOS integration test share: open a
// file from the explorer, edit it in the YAML editor's text mode, undo
// through the shell, edit again and save through the shell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_lite_example/main.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show YamlSchemaEditor;

/// A surface large enough for the shell's three panels.
Future<void> prepareSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps until [done] holds (the shell reads files asynchronously), at most
/// [tries] frames 20 ms apart.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  String what = 'the condition',
  int tries = 250,
}) async {
  for (var i = 0; i < tries; i++) {
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for $what');
}

/// Opens [file] with a double tap on its explorer row and answers the editor
/// the shell made for it.
Future<ForgeEditor> openFromExplorer(
  WidgetTester tester,
  LiteForgeShell lite,
  Uri file,
) async {
  final row = find.byKey(
    ValueKey<String>('forge-explorer-entry:${file.toFilePath()}'),
  );
  await pumpUntil(
    tester,
    () => row.evaluate().isNotEmpty,
    what: 'the explorer row of $file',
  );
  await tester.tap(row);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(row);
  await tester.pump();
  await pumpUntil(
    tester,
    () => lite.shell.systemState.activeEditor?.uri.path == file.path,
    what: '$file to open',
  );
  await tester.pumpAndSettle();
  return lite.shell.systemState.activeEditor!;
}

/// Edits `version:` in the YAML editor's text mode (typed into its source
/// view), undoes the edit through the shell's undo, sets `version: 3` and
/// saves through the shell's save. Leaves the save to finish: the caller
/// reads the file.
Future<void> editUndoSave(
  WidgetTester tester,
  LiteForgeShell lite,
  ForgeYamlEditor editor,
) async {
  final original = editor.getContent()!;
  expect(original, contains('version: 1'));
  expect(editor.isDirty.value, isFalse);

  // Into text mode with the editor's own toolbar button.
  await tester.tap(find.byTooltip('Switch to text mode'));
  await tester.pumpAndSettle();
  expect(editor.controller.textMode, isTrue);
  final source = find.descendant(
    of: find.byType(YamlSchemaEditor),
    matching: find.byType(EditableText),
  );
  expect(source, findsOneWidget);

  // An edit, typed.
  await tester.enterText(
    source,
    original.replaceFirst('version: 1', 'version: 2'),
  );
  await tester.pumpAndSettle();
  expect(editor.getContent(), contains('version: 2'));
  expect(editor.isDirty.value, isTrue);

  // Undone by the shell: its undo action goes to the active editor.
  expect(lite.shell.executeAction(StandardEditingActions.undoActionId), isTrue);
  await tester.pumpAndSettle();
  expect(editor.getContent(), original);

  // A second edit, saved by the shell's save.
  await tester.enterText(
    source,
    original.replaceFirst('version: 1', 'version: 3'),
  );
  await tester.pumpAndSettle();
  expect(editor.isDirty.value, isTrue);
  expect(lite.shell.executeAction('file.save'), isTrue);
  await pumpUntil(
    tester,
    () => !editor.isDirty.value,
    what: 'the save to finish',
  );
}

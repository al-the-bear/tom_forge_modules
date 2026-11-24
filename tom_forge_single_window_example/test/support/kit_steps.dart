// The steps the widget test and the macOS integration test share: open the
// file in the window, edit it in the YAML editor's text mode, undo through
// the window's Edit menu, edit again and save with the toolbar's Save.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_single_window_example/main.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show forgeMenuEntryKey;
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show YamlSchemaEditor;

/// A surface the size of a desktop window.
Future<void> prepareSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps until [done] holds (the kit reads and writes files
/// asynchronously), at most [tries] frames 20 ms apart.
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

/// Opens [file] in [tool]'s window and answers its editor, the window's
/// one and the kit's active editor.
Future<ForgeYamlEditor> openInWindow(
  WidgetTester tester,
  KitYamlTool tool,
  Uri file,
) async {
  await tester.runAsync(() => tool.open(file));
  await pumpUntil(
    tester,
    () => tool.api.state.activeEditor?.uri.path == file.path,
    what: '$file to open',
  );
  await tester.pumpAndSettle();
  final editor = tool.editor;
  expect(editor, isA<ForgeYamlEditor>());
  expect(identical(tool.api.state.activeEditor, editor), isTrue);
  return editor! as ForgeYamlEditor;
}

/// Runs the menu entry [actionId] of the window's menu at [location]: opens
/// the menu with its button and taps the entry.
Future<void> runMenuEntry(
  WidgetTester tester,
  ForgeMenuLocation location,
  String actionId,
) async {
  await tester.tap(find.byKey(kitMenuButtonKey(location)));
  await tester.pumpAndSettle();
  final entry = find.byKey(forgeMenuEntryKey(actionId));
  expect(entry, findsOneWidget, reason: '$actionId in the $location menu');
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

/// Edits `version:` in the YAML editor's text mode, undoes the edit with
/// Edit > Undo, sets `version: 3` and saves with the toolbar's Save. Leaves
/// the save to finish: the caller reads the file.
Future<void> editUndoSave(
  WidgetTester tester,
  KitYamlTool tool,
  ForgeYamlEditor editor,
) async {
  final original = editor.getContent()!;
  expect(original, contains('version: 1'));
  expect(editor.isDirty.value, isFalse);
  expect(tool.api.isActionEnabled(kitSaveActionId), isFalse);

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
  expect(
    find.textContaining('unsaved changes'),
    findsOneWidget,
    reason: 'the status line shows the edit',
  );

  // Undone with the window's Edit menu (the kit routes it to the editor).
  await runMenuEntry(
    tester,
    ForgeMenuLocation.edit,
    StandardEditingActions.undoActionId,
  );
  expect(editor.getContent(), original);
  expect(editor.isDirty.value, isFalse);

  // A second edit, saved with the toolbar's Save. The menu took the focus:
  // back into the source view first, as the user clicks into it.
  await tester.tap(source);
  await tester.pumpAndSettle();
  await tester.enterText(
    source,
    original.replaceFirst('version: 1', 'version: 3'),
  );
  await tester.pumpAndSettle();
  expect(editor.isDirty.value, isTrue);
  final save = find.byKey(const ValueKey('forge.actionBar.$kitSaveActionId'));
  expect(save, findsOneWidget);
  await tester.tap(save);
  await pumpUntil(
    tester,
    () => !editor.isDirty.value,
    what: 'the save to finish',
  );
  await tester.pumpAndSettle();
  expect(find.textContaining('unsaved changes'), findsNothing);
}

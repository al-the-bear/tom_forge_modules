/// `ForgeEditorSurface` on a bare `DefaultKitApi`, no shell: the editor is
/// reported to the kit state, and undo, redo, the clipboard and find reach
/// it through the kit — by key, by `api.undo()` / `api.redo()` and by
/// `api.executeAction`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/text_types.dart' show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

import 'support/bare_kit.dart';
import 'support/test_text_editor.dart';

/// Presses [key] with the primary modifier (Ctrl in the test's platform).
Future<void> _primary(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(testTextEditorTextKey)).data!;

void main() {
  late DefaultKitApi api;
  late MemoryClipboard clipboard;
  late TestTextEditor editor;

  Future<void> pumpSurface(WidgetTester tester) async {
    clipboard = MemoryClipboard();
    api = bareKit(clipboard: clipboard);
    editor = TestTextEditor(clipboard: api.clipboard, text: 'abc');
    await tester.pumpWidget(
      themed(ForgeEditorSurface(api: api, editor: editor, autofocus: true)),
    );
    await tester.pump();
  }

  testWidgets('FES-1: the editor is open and, focused, active in the kit; '
      'gone when the surface goes', (tester) async {
    await pumpSurface(tester);
    expect(api.state.openEditors, contains(editor));
    expect(api.state.activeEditor, same(editor));
    expect(api.state.focusedComponent, same(editor));
    expect(find.text('abc'), findsOneWidget);

    await tester.pumpWidget(themed(const SizedBox()));
    expect(api.state.openEditors, isNot(contains(editor)));
    expect(api.actionRegistry.getAction(forgeFindActionId), isNull);
  });

  testWidgets('FES-2: undo and redo through the kit: api.undo / api.redo, '
      'the action ids and their keys', (tester) async {
    await pumpSurface(tester);
    editor
      ..select(3, 3)
      ..type('d')
      ..type('e');
    await tester.pump();
    expect(_shown(tester), 'abcde');

    expect(api.undo(), isTrue);
    await tester.pump();
    expect(_shown(tester), 'abcd');
    expect(api.redo(), isTrue);
    await tester.pump();
    expect(_shown(tester), 'abcde');

    await _primary(tester, LogicalKeyboardKey.keyZ);
    expect(_shown(tester), 'abcd');
    await _primary(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(_shown(tester), 'abcde');

    expect(api.executeAction(StandardEditingActions.undoActionId), isTrue);
    await tester.pump();
    expect(_shown(tester), 'abcd');

    expect(editor.executed, [
      StandardEditingActions.undoActionId,
      StandardEditingActions.redoActionId,
      StandardEditingActions.undoActionId,
      StandardEditingActions.redoActionId,
      StandardEditingActions.undoActionId,
    ]);
    // Nothing more to redo after a new edit: the kit refuses it.
    editor.type('x');
    expect(api.redo(), isFalse);
  });

  testWidgets('FES-3: copy, cut and paste through the kit\'s clipboard', (
    tester,
  ) async {
    await pumpSurface(tester);
    // Nothing selected: copy is not enabled, the kit refuses it.
    editor.select(1, 1);
    expect(api.isActionEnabled(StandardEditingActions.copyActionId), isFalse);

    editor.select(0, 2);
    await _primary(tester, LogicalKeyboardKey.keyC);
    expect(clipboard.text, 'ab');

    editor.select(3, 3);
    await _primary(tester, LogicalKeyboardKey.keyV);
    await tester.pump();
    expect(editor.text, 'abcab');

    editor.select(0, 1);
    expect(api.executeAction(StandardEditingActions.cutActionId), isTrue);
    await tester.pump();
    expect(clipboard.text, 'a');
    expect(_shown(tester), 'bcab');

    clipboard.text = 'Z';
    editor.select(0, 0);
    expect(api.executeAction(StandardEditingActions.pasteActionId), isTrue);
    // The clipboard answers asynchronously; the text shows a frame later.
    await tester.pump();
    await tester.pump();
    expect(_shown(tester), 'Zbcab');
  });

  testWidgets('FES-4: find through the kit opens the surface\'s field and '
      'searches the editor; Enter moves on, Escape closes', (tester) async {
    await pumpSurface(tester);
    editor
      ..select(3, 3)
      ..type(' abc');
    await tester.pump();
    expect(api.actionRegistry.getAction(forgeFindActionId), isNotNull);
    expect(api.shortcuts.getBinding(forgeFindActionId), isNotNull);

    expect(api.executeAction(forgeFindActionId), isTrue);
    await tester.pump();
    expect(find.byKey(forgeEditorSurfaceFindFieldKey), findsOneWidget);

    await tester.enterText(find.byKey(forgeEditorSurfaceFindFieldKey), 'bc');
    await tester.pump();
    expect(editor.queries.last, 'bc');
    expect(editor.selection, 'bc');
    expect(
      tester.widget<Text>(find.byKey(forgeEditorSurfaceFindStatusKey)).data,
      '1/2',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(forgeEditorSurfaceFindStatusKey)).data,
      '2/2',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(forgeEditorSurfaceFindFieldKey), findsNothing);
    expect(editor.findStatus.value, ForgeFindStatus.none);

    // The key opens it again.
    await _primary(tester, LogicalKeyboardKey.keyF);
    expect(find.byKey(forgeEditorSurfaceFindFieldKey), findsOneWidget);
  });

  testWidgets('FES-5: a Find another owner registered is left to it', (
    tester,
  ) async {
    clipboard = MemoryClipboard();
    api = bareKit(clipboard: clipboard);
    final runs = <String>[];
    final own = recordingAction(forgeFindActionId, runs, label: 'Find');
    api.actionRegistry.registerAction(own);
    editor = TestTextEditor(clipboard: api.clipboard, text: 'abc');
    await tester.pumpWidget(
      themed(ForgeEditorSurface(api: api, editor: editor, autofocus: true)),
    );
    await tester.pump();
    expect(api.actionRegistry.getAction(forgeFindActionId), same(own));
    api.executeAction(forgeFindActionId);
    await tester.pump();
    expect(runs, [forgeFindActionId]);
    expect(find.byKey(forgeEditorSurfaceFindFieldKey), findsNothing);
    await tester.pumpWidget(themed(const SizedBox()));
    expect(api.actionRegistry.getAction(forgeFindActionId), same(own));
  });
}

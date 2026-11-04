/// The plain-text editor edits a file session (wonecmpc23): a burst of typing
/// is one entry, undone and redone through the editor's standard editing
/// actions; moving the caret never makes the file dirty; Save writes the file
/// through the session, and a file changed on disk is not written over.
/// Nothing reaches the shell's undo manager, which holds shell actions only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'Test Shell',
  navigatorKey: GlobalKey<NavigatorState>(),
);

Future<void> _mount(WidgetTester tester, ForgePlainTextEditor editor) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Builder(builder: editor.buildMain))),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PTE-UNDO-1: a burst of typing is one change that undo takes '
      'back and redo puts back', (tester) async {
    final shell = _shell();
    final module = TomForgeShellModule()..activate(shell);
    final editor = ForgePlainTextEditor.fromContent(
      content: 'one',
      uri: Uri.parse('file:///notes.txt'),
      module: module,
    );
    await _mount(tester, editor);

    await tester.enterText(find.byType(TextField), 'one t');
    await tester.enterText(find.byType(TextField), 'one tw');
    await tester.enterText(find.byType(TextField), 'one two');
    await tester.pump(const Duration(milliseconds: 400));
    expect(editor.session.history, hasLength(1), reason: 'one burst');

    expect(editor.executeAction(StandardEditingActions.undoActionId), isTrue);
    await tester.pump();
    expect(editor.session.text, 'one');
    expect(find.text('one'), findsOneWidget);

    expect(editor.executeAction(StandardEditingActions.redoActionId), isTrue);
    await tester.pump();
    expect(editor.session.text, 'one two');
    expect(
      shell.undoManager.undoCount + shell.undoManager.redoCount,
      0,
      reason: 'no shell entry for an editor edit',
    );
    await tester.pump(const Duration(seconds: 2)); // the typing pause
  });

  testWidgets('PTE-UNDO-2: clicking and selecting do not make the file dirty; '
      'a caret move ends the typing burst', (tester) async {
    final editor = ForgePlainTextEditor.fromContent(
      content: 'hello world',
      uri: Uri.parse('file:///notes.txt'),
      module: TomForgeShellModule()..activate(_shell()),
    );
    await _mount(tester, editor);
    final field = tester.widget<EditableText>(find.byType(EditableText));

    await tester.tapAt(tester.getCenter(find.byType(TextField)));
    await tester.pump();
    field.controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    field.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 5,
    );
    await tester.pump();
    expect(editor.isDirty.value, isFalse);
    expect(editor.session.canUndo, isFalse);

    field.controller.value = const TextEditingValue(
      text: 'hello world!',
      selection: TextSelection.collapsed(offset: 12),
    );
    await tester.pump();
    field.controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    field.controller.value = const TextEditingValue(
      text: '>hello world!',
      selection: TextSelection.collapsed(offset: 1),
    );
    await tester.pump();
    expect(editor.session.history, hasLength(2), reason: 'two gestures');
    expect(editor.isDirty.value, isTrue);
    await tester.pump(const Duration(seconds: 2)); // the typing pause
  });

  testWidgets('PTE-UNDO-3: Save writes the file through the session and '
      'leaves the editor clean', (tester) async {
    final fs = TomMemoryFileSystem(seed: const {'notes.txt': 'one'});
    final editor = ForgePlainTextEditor.forFile(
      fileSystem: fs,
      uri: fs.uriOf('notes.txt'),
      module: TomForgeShellModule()..activate(_shell()),
    );
    await _mount(tester, editor);
    expect(editor.getContent(), isNull, reason: 'the editor saves its file');
    await tester.enterText(find.byType(TextField), 'one two');
    await tester.pump();
    expect(editor.isDirty.value, isTrue);

    expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
    await tester.pumpAndSettle();
    expect(await fs.readText(fs.uriOf('notes.txt')), 'one two');
    expect(editor.isDirty.value, isFalse);
    await tester.pump(const Duration(seconds: 2)); // the typing pause
  });

  testWidgets('PTE-UNDO-4: a file changed on disk is not written over; the '
      'banner keeps the user\'s text or takes the disk\'s', (tester) async {
    final fs = TomMemoryFileSystem(seed: const {'notes.txt': 'one'});
    final uri = fs.uriOf('notes.txt');
    final editor = ForgePlainTextEditor.forFile(
      fileSystem: fs,
      uri: uri,
      module: TomForgeShellModule()..activate(_shell()),
    );
    await _mount(tester, editor);
    await tester.enterText(find.byType(TextField), 'mine');
    await tester.pump();
    await fs.writeText(uri, 'theirs');

    editor.executeAction(StandardEditingActions.saveActionId);
    await tester.pumpAndSettle();
    expect(await fs.readText(uri), 'theirs', reason: 'nothing written over');
    expect(find.text('This file changed on disk.'), findsOneWidget);

    await tester.tap(find.text('Take theirs'));
    await tester.pumpAndSettle();
    expect(editor.session.text, 'theirs');
    expect(find.text('theirs'), findsOneWidget);
    expect(find.text('This file changed on disk.'), findsNothing);
    await tester.pump(const Duration(seconds: 2)); // the typing pause
  });
}

/// The plain-text editor's history runs on `tom_forge_core`'s
/// `ForgeUndoStack`: a burst of typing is one change, undone and redone
/// through the shell's undo manager.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  testWidgets('PTE-UNDO-1: a burst of typing is one change that undo takes '
      'back and redo puts back', (tester) async {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Test Shell',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = TomForgeShellModule()..activate(shell);
    final editor = ForgePlainTextEditor.fromContent(
      content: 'one',
      uri: Uri.parse('file:///notes.txt'),
      module: module,
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Builder(builder: editor.buildMain))),
    );

    await tester.enterText(find.byType(TextField), 'one two');
    await tester.pump(const Duration(milliseconds: 400));
    expect(shell.undoManager.undoCount, 1, reason: 'one bridge entry');

    await shell.undoManager.undo();
    await tester.pump();
    expect(editor.controller.markdown, 'one');
    expect(find.text('one'), findsOneWidget);

    await shell.undoManager.redo();
    await tester.pump();
    expect(editor.controller.markdown, 'one two');
  });
}

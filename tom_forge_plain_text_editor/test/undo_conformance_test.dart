/// The plain-text editor under Forge's undo conformance harness, with no
/// check skipped: over a session holding the saved text, in the shell of the
/// file kind test bed, and in memory ([ForgePlainTextEditor.fromContent]).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

/// The plain-text editor over its file session.
class _PlainTextSubject extends ForgeUndoSubject {
  _PlainTextSubject(this.editor, [this.bed]);

  @override
  final ForgePlainTextEditor editor;
  final ForgeFileKindTestBed? bed;

  @override
  String textOf(WidgetTester tester) => editor.session.text;

  @override
  Future<void> saved() async {
    expect(await editor.session.save(), isNot(ForgeFileSaveOutcome.conflict));
  }

  @override
  void dispose() {
    editor.dispose();
    bed?.dispose();
  }
}

void main() {
  runForgeUndoConformance('Plain text editor (session)', (saved) {
    final bed = ForgeFileKindTestBed();
    return _PlainTextSubject(
      ForgePlainTextEditor(
        session: bed.sessionWithText('notes.txt', saved),
        module: bed.shellModule,
        api: bed.shell,
      ),
      bed,
    );
  });
  runForgeUndoConformance('Plain text editor (in memory)', (saved) {
    final bed = ForgeFileKindTestBed();
    return _PlainTextSubject(
      ForgePlainTextEditor.fromContent(
        content: saved,
        uri: Uri.parse('file:///notes.txt'),
        module: bed.shellModule,
      ),
      bed,
    );
  });
}

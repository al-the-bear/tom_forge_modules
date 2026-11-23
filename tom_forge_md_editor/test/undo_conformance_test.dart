/// The Markdown file kind's editor under Forge's undo conformance harness,
/// with no check skipped, twice: made by the kind as a file module makes it
/// (`ForgeFileKindTestBed`) and constructed directly; its controller keeps
/// the history, a save saves through the file's session. The subject is the
/// test support's (`tom_forge_md_editor_testing`), so an app composing the
/// kind runs the same checks.
library;

import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_md_editor_testing/tom_forge_md_editor_testing.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

void main() {
  // The editor as the kind makes it (the way a file module opens the
  // file), and as an application that builds it itself makes it.
  runForgeUndoConformance('Markdown file editor (kind)', (saved) {
    final bed = ForgeFileKindTestBed();
    return ForgeMarkdownFileSubject(
      bed.withText(forgeMarkdownFileKind, 'notes.md', saved),
    );
  });
  runForgeUndoConformance('Markdown file editor', (saved) {
    final bed = ForgeFileKindTestBed();
    return ForgeMarkdownFileSubject(
      ForgeMarkdownFileEditor(
        session: bed.sessionWithText('notes.md', saved),
        module: bed.shellModule,
        api: bed.shell,
      ),
    );
  });
}

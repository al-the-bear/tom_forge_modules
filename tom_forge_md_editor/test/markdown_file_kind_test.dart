/// The Markdown file kind: it takes `.md` and `.markdown` files; its editor,
/// made as a file module makes it, reads the file through its session,
/// undoes through the editor's history and saves its own file — the
/// application writes nothing — keeping the byte-order mark and the CRLF
/// line endings.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart' show saveOwnedEditor;
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

List<int> _bom(String text) => [0xEF, 0xBB, 0xBF, ...utf8.encode(text)];

void main() {
  test('MFK-1: the kind takes Markdown files, any case', () {
    expect(forgeMarkdownFileKind.id, 'markdown');
    expect(forgeMarkdownFileKind.matches('notes.md'), isTrue);
    expect(forgeMarkdownFileKind.matches('README.MARKDOWN'), isTrue);
    expect(forgeMarkdownFileKind.matches('notes.txt'), isFalse);
  });

  testWidgets('MFK-2: undo, dirty and a save that keeps the BOM and the CRLF '
      'line endings', (tester) async {
    final bed = ForgeFileKindTestBed();
    addTearDown(bed.dispose);
    await bed.write('/a.md', _bom('# A\r\n\r\nfirst\r\n'));
    final editor = bed.open<ForgeMarkdownFileEditor>(
      forgeMarkdownFileKind,
      '/a.md',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: editor.buildMain)),
      ),
    );
    await tester.pumpAndSettle();
    expect(editor.controller.markdown, '# A\n\nfirst\n');
    expect(
      editor.getContent(),
      isNull,
      reason: 'the application writes nothing',
    );
    editor.controller.applyEdit('# A\n\nfirst\nsecond\n');
    await tester.pump();
    expect(editor.isDirty.value, isTrue);
    expect(editor.executeAction(StandardEditingActions.undoActionId), isTrue);
    await tester.pump();
    expect(editor.isDirty.value, isFalse);
    expect(editor.executeAction(StandardEditingActions.redoActionId), isTrue);
    await tester.pump();
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(await bed.read('/a.md'), _bom('# A\r\n\r\nfirst\r\nsecond\r\n'));
    expect(editor.isDirty.value, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });
}

/// The PDF editors at the narrowest size the shell lays an editor out at
/// (`sizeHints.minSize`): nothing overflows. Overflow errors are not
/// suppressed here: one fails the test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart' show ForgeEditor;
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'support/workspace.dart';

Future<void> _showAt(WidgetTester tester, ForgeEditor editor, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: Builder(builder: editor.buildMain),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FPDF-NARROW-1: the PDFium editor, opening and open with its '
      'find bar, fits its minimum size', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgePdfEditor;
    final min = editor.sizeHints.minSize;
    expect(min.width, 240);
    await _showAt(tester, editor, min);
    expect(tester.takeException(), isNull, reason: 'first frame');
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 50 && editor.controller.state != TomPdfEditorState.open;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(editor.controller.state, TomPdfEditorState.open);
    editor.controller.showFind();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'open');
  });

  testWidgets('FPDFJS-NARROW-1: the pdf.js editor fits its minimum size', (
    tester,
  ) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.editorChoicesFor(a)[1].open(a);
    final js = w.editorOf(a)! as ForgePdfJsEditor;
    await _showAt(tester, js, js.sizeHints.minSize);
    expect(tester.takeException(), isNull);
  });
}

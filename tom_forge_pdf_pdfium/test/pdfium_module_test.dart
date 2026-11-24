/// The PDFium editor in a bare kit (no shell): the module opens `.pdf` files
/// itself in the PDFium editor, shows an editor already open, offers it
/// under Open With; the application's save, undo, redo and dirty reach the
/// controller; a closed editor gives its document up and the next open
/// starts clean; focus checks the file for outside changes; links go to the
/// application's openExternal.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'support/workspace.dart';

const _save = StandardEditingActions.saveActionId;
const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

void main() {
  testWidgets('FPDF-OPEN-1: a .pdf (any case) opens in the PDFium editor, '
      'once; other files and files without a path are declined', (
    tester,
  ) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final b = w.add('/docs/B.PDF');
    expect(w.module.openUri(a), isTrue);
    final editor = w.editorOf(a);
    expect(editor, isA<ForgePdfEditor>());
    expect(w.module.openUri(a), isTrue);
    expect(w.api.state.openEditors.where((e) => e.uri == a), hasLength(1));
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgePdfEditor>());
    expect(w.module.handles(Uri.file('/docs/notes.txt')), isFalse);
    expect(w.module.openUri(w.fs.uriOf('/docs/notes.txt')), isFalse);
    expect(w.module.openUri(Uri.parse('https://example.org/x.pdf')), isFalse);
    expect(w.module.editorChoicesFor(w.fs.uriOf('/docs/notes.txt')), isEmpty);
    await w.show(tester, editor!);
    expect(find.byType(TomPdfEditor), findsOneWidget);
    expect((editor as ForgePdfEditor).controller.state, TomPdfEditorState.open);
  });

  testWidgets('FPDF-CHOICE-1: Open With offers the PDFium editor; the '
      'choice opens its editor once; a file-type default naming no other '
      'module\'s choice leaves openUri on PDFium', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final choices = w.module.editorChoicesFor(a);
    expect(choices.map((c) => c.id), [ForgePdfiumModule.pdfiumChoiceId]);
    choices.single.open(a);
    final editor = w.editorOf(a);
    expect(editor, isA<ForgePdfEditor>());
    choices.single.open(a);
    expect(w.api.state.openEditors.where((e) => e.uri == a), hasLength(1));

    final b = w.add('/docs/b.pdf');
    w.api.setFileTypeDefault('pdf', 'pdf.pdfjs');
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgePdfEditor>(), reason: 'no pdf.js module');
  });

  testWidgets('FPDF-ROUTE-1: the application\'s undo, redo and save reach the '
      'controller; dirty and the state stream follow it', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgePdfEditor;
    await w.show(tester, editor);
    final states = <void>[];
    final sub = editor.onStateChanged.listen(states.add);
    addTearDown(sub.cancel);
    expect(editor.getContent(), isNull);
    expect(editor.supportedActionIds, containsAll([_save, _undo, _redo]));
    expect(editor.isActionEnabled(_undo), isFalse);

    await editor.controller.addNote(0, 50, 50, 'a note');
    await tester.pumpAndSettle();
    expect(editor.isDirty.value, isTrue);
    expect(editor.isActionEnabled(_undo), isTrue);
    expect(states, isNotEmpty);

    expect(editor.executeAction(_undo), isTrue);
    await tester.pumpAndSettle();
    expect(editor.controller.annotationsOn(0), isEmpty);
    expect(editor.isDirty.value, isFalse);
    expect(editor.isActionEnabled(_redo), isTrue);
    editor.executeAction(_redo);
    await tester.pumpAndSettle();
    expect(editor.controller.annotationsOn(0), hasLength(1));

    // An explicit save goes to the editor, an automatic one does not.
    expect(
      saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic),
      isFalse,
    );
    expect(utf8.decode(w.files.read('/docs/a.pdf')!), '%PDF-/docs/a.pdf');
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(utf8.decode(w.files.read('/docs/a.pdf')!), '%PDF-saved');
    expect(editor.isDirty.value, isFalse);
  });

  testWidgets('FPDF-REOPEN-1: replaceContent answers false; the closed '
      'editor gives its document up and the next open starts clean with an '
      'empty history', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.openUri(a);
    final first = w.editorOf(a)! as ForgePdfEditor;
    await w.show(tester, first);
    await first.controller.addNote(0, 50, 50, 'x');
    await tester.pumpAndSettle();
    expect(first.replaceContent('text'), isFalse);
    await tester.pumpWidget(const SizedBox());
    await w.kit.close(first);
    await tester.pumpAndSettle();
    expect(w.module.editors, isEmpty);
    expect(w.engine.releases, 1, reason: 'the engine share given up');
    w.module.openUri(a);
    final second = w.editorOf(a)! as ForgePdfEditor;
    expect(identical(first, second), isFalse);
    await w.show(tester, second);
    expect(second.isDirty.value, isFalse);
    expect(second.isActionEnabled(_undo), isFalse);
  });

  testWidgets('FPDF-FOCUS-1: when the window regains focus a clean editor '
      'reopens a file changed on disk', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgePdfEditor;
    await w.show(tester, editor);
    expect(editor.controller.generation, 0);
    w.files.write('/docs/a.pdf', utf8.encode('%PDF-changed'));
    w.focus.add(null);
    await tester.pumpAndSettle();
    expect(editor.controller.generation, 1);
    // The reload notice's toast runs out.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('FPDF-SPLIT-1: the PDFium editor\'s copy is a second view of '
      'the same controller', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgePdfEditor;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Row(
              children: [
                Expanded(child: editor.buildMain(context)),
                Expanded(child: editor.buildCopy(context)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final views = tester.widgetList<TomPdfEditor>(find.byType(TomPdfEditor));
    expect(views, hasLength(2));
    expect(views.map((v) => v.controller).toSet(), {editor.controller});
    expect(tester.takeException(), isNull);
  });

  testWidgets('FPDF-LINK-1: a link of the document goes to the '
      'application\'s openExternal', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgePdfEditor;
    editor.host.openLink('https://example.org/page');
    editor.host.openLink('http://[bad');
    expect(w.links, [Uri.parse('https://example.org/page')]);
  });
}

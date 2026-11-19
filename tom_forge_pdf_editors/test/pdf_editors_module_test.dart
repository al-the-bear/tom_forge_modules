/// The PDF editors in a Forge shell: the module opens `.pdf` files itself in
/// the default editor (PDFium) or the one the file-type default names, shows
/// an editor already open, offers both under Open With; the shell's save,
/// undo, redo and dirty reach the controllers; a closed editor gives its
/// document up and the next open starts clean; focus checks the file for
/// outside changes; the pdf.js editor switches mode from the tab's actions.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_pdf_editors_testing/tom_forge_pdf_editors_testing.dart';
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_pdf_editor/pdfjs.dart';
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
    expect(
      w.shell.systemState.openEditors.where((e) => e.uri == a),
      hasLength(1),
    );
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

  testWidgets('FPDF-CHOICE-1: Open With offers both editors; each choice '
      'opens its editor once, both may be open on one file; the file-type '
      'default picks the editor openUri opens', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final choices = w.module.editorChoicesFor(a);
    expect(choices.map((c) => c.id), [
      ForgePdfEditorsModule.pdfiumChoiceId,
      ForgePdfEditorsModule.pdfJsChoiceId,
    ]);
    choices[1].open(a);
    final js = w.editorOf(a);
    expect(js, isA<ForgePdfJsEditor>());
    expect((js! as ForgePdfJsEditor).mode, TomPdfJsMode.components);
    choices[1].open(a);
    choices[0].open(a);
    final open = w.shell.systemState.openEditors.where((e) => e.uri == a);
    expect(open.map((e) => e.runtimeType).toSet(), {
      ForgePdfJsEditor,
      ForgePdfEditor,
    });
    expect(open, hasLength(2));

    final b = w.add('/docs/b.pdf');
    (w.shell.layout as DefaultLayoutController).setFileTypeDefaultEditor(
      'pdf',
      ForgePdfEditorsModule.pdfJsChoiceId,
    );
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgePdfJsEditor>());
  });

  testWidgets('FPDF-ROUTE-1: the shell\'s undo, redo and save reach the '
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
    w.shell.layout.closeEditor(first);
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
    (w.shell.systemState as DefaultSystemState).setWindowFocused(true);
    await tester.pumpAndSettle();
    expect(editor.controller.generation, 1);
    // The reload notice's toast runs out.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('FPDF-SPLIT-1: the PDFium editor\'s copy is a second view of '
      'the same controller; the pdf.js editor\'s copy says it cannot split', (
    tester,
  ) async {
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

    w.module.editorChoicesFor(a)[1].open(a);
    final js = w.editorOf(a)! as ForgePdfJsEditor;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: js.buildCopy)),
      ),
    );
    expect(find.text('This view cannot be split.'), findsOneWidget);
    expect(find.text('Show the main view'), findsOneWidget);
  });

  group('the pdf.js editor', () {
    testWidgets('FPDFJS-1: opens in components mode; the tab\'s actions '
        'switch to integrated and full; a dirty document is not switched', (
      tester,
    ) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      w.module.editorChoicesFor(a)[1].open(a);
      final js = w.editorOf(a)! as ForgePdfJsEditor;
      await w.show(tester, js);
      final page = w.pages.single;
      expect(
        page.loads.single.path,
        endsWith('/pdfjs/web/forge/components.html'),
      );
      expect(js.controller.state, TomPdfJsState.open);
      expect(js.headerActions.map((x) => x.label), [
        'pdf.js view: components',
        'pdf.js view: integrated',
        'pdf.js view: full',
      ]);
      expect(js.headerActions.first.isEnabled(), isFalse);

      await js.headerActions[1].execute({});
      await tester.pumpAndSettle();
      expect(js.mode, TomPdfJsMode.integrated);
      expect(
        page.loads.last.path,
        endsWith('/pdfjs/web/forge-integrated.html'),
      );
      expect(js.titleExtension.value, 'pdf.js integrated');
      expect(js.controller.state, TomPdfJsState.open);

      page.add('ink');
      await tester.pumpAndSettle();
      expect(js.isDirty.value, isTrue);
      expect(js.setMode(TomPdfJsMode.full), isFalse);
      expect(js.mode, TomPdfJsMode.integrated);
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('FPDFJS-ROUTE-1: undo, redo and save go to the page; history '
        'and dirty come back from it', (tester) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      w.module.editorChoicesFor(a)[1].open(a);
      final js = w.editorOf(a)! as ForgePdfJsEditor;
      await w.show(tester, js);
      final page = w.pages.single;
      page.add('highlight');
      await tester.pumpAndSettle();
      expect(js.isActionEnabled(_undo), isTrue);
      expect(js.isDirty.value, isTrue);
      js.executeAction(_undo);
      await tester.pumpAndSettle();
      expect(page.callNames, contains('undo'));
      expect(page.annotations, isEmpty);
      expect(js.isActionEnabled(_redo), isTrue);
      js.executeAction(_redo);
      await tester.pumpAndSettle();
      expect(page.annotations, ['highlight']);
      // Save asks the page for its bytes; the page's failure ends it.
      expect(saveOwnedEditor(js), isTrue);
      await tester.pump();
      expect(page.callNames.last, 'save');
      page.send({'type': 'error', 'kind': 'save', 'message': 'no route'});
      await tester.pumpAndSettle();
      expect(js.controller.state, TomPdfJsState.open);
      // The save error's toast runs out.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('FPDFJS-REOPEN-1: replaceContent answers false; closing the '
        'editor closes the page and the next open starts anew', (tester) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      w.module.editorChoicesFor(a)[1].open(a);
      final js = w.editorOf(a)! as ForgePdfJsEditor;
      await w.show(tester, js);
      expect(js.replaceContent('x'), isFalse);
      final page = w.pages.single;
      await tester.pumpWidget(const SizedBox());
      w.shell.layout.closeEditor(js);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(page.callNames, contains('close'));
      expect(js.controller.state, TomPdfJsState.closed);
      w.pages.add(ScriptedPdfJsPage());
      w.module.editorChoicesFor(a)[1].open(a);
      final again = w.editorOf(a)! as ForgePdfJsEditor;
      expect(identical(js, again), isFalse);
      unawaited(again.close());
    });
  });
}

/// The pdf.js editor in a bare kit (no shell): the module offers it under
/// Open With and opens a `.pdf` itself only when the file-type default names
/// it; it opens in full mode and switches mode from the tab's actions; the
/// application's save, undo, redo and dirty reach the page; a closed editor
/// closes its page; focus checks the file for outside changes. With the
/// PDFium module beside it (as an application composes them): Open With
/// offers both, PDFium is the default, the default naming pdf.js opens it,
/// and a PDF editor already open on the file is shown.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart';
import 'package:tom_forge_pdf_pdfjs_testing/tom_forge_pdf_pdfjs_testing.dart';
import 'package:tom_pdf_pdfjs/tom_pdf_pdfjs.dart';

import 'support/workspace.dart';

const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

void main() {
  testWidgets('FPDFJS-CHOICE-1: Open With offers the pdf.js editor, which '
      'opens once per file; openUri leaves a .pdf to the default editor '
      'unless the file-type default names pdf.js; other files are declined', (
    tester,
  ) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    expect(w.module.editorChoicesFor(a).map((c) => c.id), [
      ForgePdfJsModule.pdfJsChoiceId,
    ]);
    expect(w.module.openUri(a), isFalse, reason: 'not the default');
    final js = w.openJs(a);
    expect(js.mode, TomPdfJsMode.full);
    w.module.editorChoicesFor(a).single.open(a);
    expect(w.api.state.openEditors.where((e) => e.uri == a), hasLength(1));
    expect(w.module.handles(Uri.file('/docs/B.PDF')), isTrue);
    expect(w.module.editorChoicesFor(w.fs.uriOf('/docs/notes.txt')), isEmpty);
    expect(w.module.openUri(Uri.parse('https://example.org/x.pdf')), isFalse);

    final b = w.add('/docs/b.pdf');
    w.api.setFileTypeDefault('pdf', ForgePdfJsModule.pdfJsChoiceId);
    w.pages.add(ScriptedPdfJsPage());
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgePdfJsEditor>());
  });

  testWidgets('FPDF-CHOICE-2: with both PDF modules Open With offers both; '
      'PDFium opens a .pdf by default; each choice opens its editor once, '
      'both may be open on one file; the file-type default naming pdf.js '
      'opens pdf.js; a PDF editor already open on the file is shown', (
    tester,
  ) async {
    final w = Workspace(withPdfium: true);
    final pdfium = w.pdfium!;
    final a = w.add('/docs/a.pdf');
    final choices = [
      ...pdfium.editorChoicesFor(a),
      ...w.module.editorChoicesFor(a),
    ];
    expect(choices.map((c) => c.id), ['pdf.pdfium', 'pdf.pdfjs']);
    choices[1].open(a);
    final js = w.editorOf(a);
    expect(js, isA<ForgePdfJsEditor>());
    // Opening the file again shows the pdf.js editor already open on it.
    expect(pdfium.openUri(a), isTrue);
    expect(w.api.state.activeEditor, same(js));
    expect(w.api.state.openEditors.where((e) => e.uri == a), hasLength(1));
    choices[0].open(a);
    final open = w.api.state.openEditors.where((e) => e.uri == a).toList();
    expect(open, hasLength(2));
    expect(open.first, same(js));
    expect(pdfium.editors, [open.last], reason: 'the PDFium editor');

    final b = w.add('/docs/b.pdf');
    expect(pdfium.openUri(b), isTrue);
    expect(pdfium.editors, contains(w.editorOf(b)), reason: 'the default');

    final c = w.add('/docs/c.pdf');
    w.api.setFileTypeDefault('pdf', ForgePdfJsModule.pdfJsChoiceId);
    w.pages.add(ScriptedPdfJsPage());
    expect(pdfium.openUri(c), isTrue, reason: 'it opens the default there');
    expect(w.editorOf(c), isA<ForgePdfJsEditor>());
    for (final e in [...w.module.editors]) {
      unawaited((e as ForgePdfJsEditor).close());
    }
  });

  testWidgets('FPDFJS-FOCUS-1: when the window regains focus a clean pdf.js '
      'editor reopens a file changed on disk', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    await w.show(tester, js);
    final page = w.pages.single;
    final opens = page.callNames.where((n) => n == 'open').length;
    w.files.write('/docs/a.pdf', utf8.encode('%PDF-changed'));
    w.focus.add(null);
    await tester.pumpAndSettle();
    expect(
      page.callNames.where((n) => n == 'open').length,
      greaterThan(opens),
      reason: 'a clean document reopens',
    );
    expect(js.controller.state, TomPdfJsState.open);
    // The reload notice's toast runs out.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('FPDFJS-SPLIT-1: the pdf.js editor\'s copy says it cannot '
      'split', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: js.buildCopy)),
      ),
    );
    expect(find.text('This view cannot be split.'), findsOneWidget);
    expect(find.text('Show the main view'), findsOneWidget);
    await tester.tap(find.text('Show the main view'));
    expect(w.api.state.activeEditor, same(js));
  });

  testWidgets('FPDFJS-LINK-1: a link of the document goes to the '
      'application\'s openExternal', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    js.host.openLink('https://example.org/page');
    expect(w.links, [Uri.parse('https://example.org/page')]);
  });

  testWidgets('FPDFJS-1: opens in full mode (DPEV-5); the tab\'s actions '
      'switch to components and integrated; a dirty document is not '
      'switched', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    await w.show(tester, js);
    final page = w.pages.single;
    expect(ForgePdfJsEditor.defaultMode, TomPdfJsMode.full);
    expect(page.loads.single.path, endsWith('/pdfjs/web/forge-full.html'));
    expect(js.controller.state, TomPdfJsState.open);
    expect(js.titleExtension.value, isNull, reason: 'the default mode');
    expect(js.headerActions.map((x) => x.label), [
      'pdf.js view: components',
      'pdf.js view: integrated',
      'pdf.js view: full',
    ]);
    expect(js.headerActions.last.isEnabled(), isFalse);
    expect(js.headerActions.first.isEnabled(), isTrue);

    await js.headerActions.first.execute({});
    await tester.pumpAndSettle();
    expect(js.mode, TomPdfJsMode.components);
    expect(page.loads.last.path, endsWith('/pdfjs/web/forge/components.html'));
    expect(js.titleExtension.value, 'pdf.js components');

    await js.headerActions[1].execute({});
    await tester.pumpAndSettle();
    expect(js.mode, TomPdfJsMode.integrated);
    expect(page.loads.last.path, endsWith('/pdfjs/web/forge-integrated.html'));
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
    final js = w.openJs(a);
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

  testWidgets('FPDFJS-DIRTY-1: the dirty marker follows pdf.js\'s '
      'modified state: undoing one of two edits stays dirty, undoing both '
      'reads clean (officeproto31hg)', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    await w.show(tester, js);
    final page = w.pages.single;
    expect(js.isDirty.value, isFalse);
    page
      ..add('ink A')
      ..add('ink B');
    await tester.pumpAndSettle();
    expect(js.isDirty.value, isTrue);
    js.executeAction(_undo);
    await tester.pumpAndSettle();
    expect(page.annotations, ['ink A']);
    expect(js.isDirty.value, isTrue, reason: 'edit A is still stored');
    js.executeAction(_undo);
    await tester.pumpAndSettle();
    expect(page.annotations, isEmpty);
    expect(js.isDirty.value, isFalse, reason: 'the storage is empty');
    js.executeAction(_redo);
    await tester.pumpAndSettle();
    expect(js.isDirty.value, isTrue);
  });

  testWidgets('FPDFJS-REOPEN-1: replaceContent answers false; closing the '
      'editor closes the page and the next open starts anew', (tester) async {
    final w = Workspace();
    final a = w.add('/docs/a.pdf');
    final js = w.openJs(a);
    await w.show(tester, js);
    expect(js.replaceContent('x'), isFalse);
    final page = w.pages.single;
    await tester.pumpWidget(const SizedBox());
    await w.kit.close(js);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(page.callNames, contains('close'));
    expect(js.controller.state, TomPdfJsState.closed);
    w.pages.add(ScriptedPdfJsPage());
    final again = w.openJs(a);
    expect(identical(js, again), isFalse);
    unawaited(again.close());
  });
}

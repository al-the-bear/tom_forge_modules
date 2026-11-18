/// The PDF editors as the shell's find targets, their kept view state, and
/// a PDF from a file system without local paths.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_session/tom_file_session.dart'
    show TomFileSystemBinaryFiles;
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_pdf_editor/pdfjs.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'support/workspace.dart';

/// Records the shell's Find action instead of the scaffold's find bar.
List<String> _recordFind(Workspace w) {
  final log = <String>[];
  w.shell.actionRegistry.registerAction(
    ForgeAction(
      id: 'editor.find',
      label: 'Find',
      execute: (_) async {
        log.add('editor.find');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
  );
  return log;
}

Future<void> _cmdF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pumpAndSettle();
}

void main() {
  group('the shell\'s find', () {
    testWidgets('FPDF-FIND-1: the PDFium editor is a find target; Cmd+F in '
        'it opens the shell\'s find bar, its own stays hidden', (tester) async {
      final w = Workspace();
      final log = _recordFind(w);
      final a = w.add('/docs/a.pdf');
      w.docs['/docs/a.pdf'] = FakePdfDocument(
        pages: const [PdfPageSize(300, 400), PdfPageSize(300, 400)],
        texts: const ['text one text', 'more text'],
      );
      w.module.openUri(a);
      final editor = w.editorOf(a)! as ForgePdfEditor;
      await w.show(tester, editor);
      expect(editor, isA<ForgeFindTarget>());
      expect(
        editor.supportedActionIds,
        isNot(contains('editor.find')),
        reason: 'the shell\'s Find action is the shell\'s, not routed',
      );

      // Cmd+F inside the editor.
      await tester.tap(find.byType(PdfPageView));
      await tester.pumpAndSettle();
      await _cmdF(tester);
      expect(log, ['editor.find']);
      expect(editor.controller.findVisible, isFalse);

      editor.find('text');
      await tester.pumpAndSettle();
      expect(
        editor.findStatus.value,
        const ForgeFindStatus(current: 1, total: 3),
      );
      editor.findNext();
      await tester.pumpAndSettle();
      expect(editor.findStatus.value.current, 2);
      editor.findPrevious();
      editor.findPrevious();
      await tester.pumpAndSettle();
      expect(editor.findStatus.value.current, 3, reason: 'wraps');
      editor.find('TEXT', caseSensitive: true);
      await tester.pumpAndSettle();
      expect(editor.findStatus.value.total, 0);
      editor.clearFind();
      await tester.pumpAndSettle();
      expect(editor.findStatus.value, ForgeFindStatus.none);
      expect(editor.controller.hits, isEmpty);
    });

    testWidgets('FPDFJS-FIND-1: the pdf.js editor is a find target; the '
        'page\'s Cmd+F opens the shell\'s find bar', (tester) async {
      final w = Workspace();
      final log = _recordFind(w);
      final a = w.add('/docs/a.pdf');
      w.module.editorChoicesFor(a)[1].open(a);
      final js = w.editorOf(a)! as ForgePdfJsEditor;
      await w.show(tester, js);
      final page = w.pages.single;
      page.send({'type': 'shortcut', 'key': 'find'});
      await tester.pumpAndSettle();
      expect(log, ['editor.find']);
      expect(find.byKey(const ValueKey('pdfjs-find-field')), findsNothing);

      js.find('reasoning', wholeWord: true);
      await tester.pumpAndSettle();
      final (fn, args) = page.calls.last;
      expect(fn, 'find');
      expect(args.first, 'reasoning');
      expect((args[1]! as Map)['entireWord'], isTrue);
      page.send({'type': 'findCount', 'current': 1, 'total': 4});
      await tester.pumpAndSettle();
      expect(js.findStatus.value, const ForgeFindStatus(current: 1, total: 4));
      js.findNext();
      await tester.pumpAndSettle();
      expect((page.calls.last.$2[1]! as Map)['again'], isTrue);
      js.findPrevious();
      await tester.pumpAndSettle();
      expect((page.calls.last.$2[1]! as Map)['previous'], isTrue);
      js.clearFind();
      await tester.pumpAndSettle();
      expect(page.calls.last.$2.first, '');
      expect(js.findStatus.value, ForgeFindStatus.none);
    });
  });

  group('kept view state', () {
    testWidgets('FPDF-STATE-1: the PDFium editor keeps page, offset and zoom; '
        'a new editor given the state returns there', (tester) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      w.docs['/docs/a.pdf'] = FakePdfDocument(
        pages: List.filled(10, const PdfPageSize(300, 400)),
      );
      w.module.openUri(a);
      final first = w.editorOf(a)! as ForgePdfEditor;
      first.restoreState({'page': 5, 'offset': 0.25, 'zoom': 125});
      await w.show(tester, first);
      final state = first.saveState()!;
      expect(state['route'], 'pdfium');
      expect(state['page'], 5);
      expect(state['zoom'], 125);
      expect(state['offset'] as double, closeTo(0.25, 0.01));
      expect(find.text('125 %'), findsOneWidget);

      // Closed and opened again: the shell gives the state back.
      await tester.pumpWidget(const SizedBox());
      w.shell.layout.closeEditor(first);
      await tester.pumpAndSettle();
      w.module.openUri(a);
      final second = w.editorOf(a)! as ForgePdfEditor;
      second.restoreState(state);
      await w.show(tester, second);
      final view = tester.state<PdfPageViewState>(find.byType(PdfPageView));
      expect(view.position!.$1, 5);
      expect(second.saveState()!['zoom'], 125);
      // A state of another route or a broken one is ignored.
      second.restoreState(const {'page': 'x'});
    });

    testWidgets('FPDFJS-STATE-1: the pdf.js editor keeps page and scale; a '
        'restored state is applied when the page has loaded and survives a '
        'mode switch', (tester) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      w.module.editorChoicesFor(a)[1].open(a);
      final js = w.editorOf(a)! as ForgePdfJsEditor;
      js.restoreState({'page': 3, 'scale': '1.25'});
      await w.show(tester, js);
      final page = w.pages.single;
      final names = page.callNames;
      expect(names.sublist(names.indexOf('open')), [
        'open',
        'zoom',
        'scrollTo',
      ]);
      expect(page.calls.last.$2, [4]);
      page.send({'type': 'view', 'page': 6, 'scale': 'page-width'});
      await tester.pumpAndSettle();
      expect(js.saveState(), {
        'route': 'pdfjs',
        'page': 5,
        'scale': 'page-width',
      });

      expect(js.setMode(TomPdfJsMode.full), isTrue);
      await tester.pumpAndSettle();
      expect(page.loads.last.path, endsWith('/pdfjs/web/forge-full.html'));
      final calls = page.callNames;
      expect(calls.sublist(calls.lastIndexOf('open')), [
        'open',
        'zoom',
        'scrollTo',
      ]);
      expect(page.calls.last.$2, [6]);
    });
  });

  testWidgets('FPDF-REMOTE-1: a PDF of a file system without local paths '
      'opens from its bytes and saves through the file system', (tester) async {
    final w = Workspace(root: Uri.parse('memory://remote/'));
    final uri = w.fs.uriOf('docs/r.pdf');
    final original = Uint8List.fromList(utf8.encode('%PDF-remote'));
    await tester.runAsync(() => w.fs.write(uri, original));
    w.docs[FakePdfEngine.bytesKey(original)] = FakePdfDocument(
      pages: const [PdfPageSize(300, 400)],
      texts: const ['remote text'],
    );
    expect(uri.isScheme('file'), isFalse);
    expect(w.module.openUri(uri), isTrue);
    final editor = w.editorOf(uri)! as ForgePdfEditor;
    expect(editor.host.files, isA<TomFileSystemBinaryFiles>());
    expect(editor.host.filePath, 'docs/r.pdf');
    await w.show(tester, editor);
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 20 && editor.controller.state != TomPdfEditorState.open;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(editor.controller.state, TomPdfEditorState.open);
    expect(w.engine.calls, contains('openBytes ${original.length}'));

    await tester.runAsync(
      () => editor.controller.addNote(0, 40, 40, 'remote note'),
    );
    await tester.pumpAndSettle();
    expect(editor.isDirty.value, isTrue);
    expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && editor.controller.generation == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(() => w.fs.read(uri)))!.bytes;
    expect(utf8.decode(saved), '%PDF-saved-1');
    expect(editor.isDirty.value, isFalse);
    expect(editor.controller.generation, 1, reason: 'reopened from the bytes');
    final notes = (await tester.runAsync(
      () => editor.controller.loadAnnotations(0),
    ))!;
    expect(notes.map((a) => a.contents), [
      'remote note',
    ], reason: 'the reopened document holds the saved note');
  });
}

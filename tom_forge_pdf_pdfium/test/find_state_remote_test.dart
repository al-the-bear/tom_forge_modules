/// The PDFium editor as the application's find target, its kept view state,
/// and a PDF from a file system without local paths.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_session/tom_file_session.dart'
    show TomFileSystemBinaryFiles;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart';
import 'package:tom_pdf_editor/testing.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'support/workspace.dart';

/// Records the application's Find action instead of a find bar.
List<String> _recordFind(Workspace w) {
  final log = <String>[];
  w.api.actionRegistry.registerAction(
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
  group('the application\'s find', () {
    testWidgets('FPDF-FIND-1: the PDFium editor is a find target; Cmd+F in '
        'it opens the application\'s find bar, its own stays hidden', (
      tester,
    ) async {
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
        reason: 'the Find action is the application\'s, not routed',
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

      // Closed and opened again: the application gives the state back.
      await tester.pumpWidget(const SizedBox());
      await w.kit.close(first);
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

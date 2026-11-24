/// The ZetaOffice module in a Forge shell (registered as a kit module): it
/// offers its editor under Open With for the office kinds (`.csv` too), opens
/// a file itself only when the file-type default names it (or, opening by
/// default, when none is set); the application's save, undo, redo and dirty
/// reach the controller; its split copy says it cannot split; a closed
/// editor closes its page and frees the slot; whether ZetaOffice is
/// available without LibreOffice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart';
import 'package:tom_forge_office_zetaoffice_testing/tom_forge_office_zetaoffice_testing.dart';
import 'package:tom_office_zetaoffice/testing.dart';
import 'package:tom_office_zetaoffice/tom_office_zetaoffice.dart';

const _save = StandardEditingActions.saveActionId;
const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

/// ZetaOffice's files are not cached and the CDN does not answer.
class _OfflineZetaFiles extends FakeZetaOfficeFiles {
  _OfflineZetaFiles() : super(state: TomZetaOfficeCacheState.missing);

  @override
  Future<int> downloadSize() => Future.error(StateError('offline'));
}

void main() {
  testWidgets('FZO-OPEN-1: Open With offers ZetaOffice for the office kinds '
      '(any case, .csv too), once per file; openUri opens a file only when '
      'its default names ZetaOffice; files without a local path are not '
      'offered', (tester) async {
    final w = ForgeZetaOfficeWorkspace();
    final a = await w.add('/docs/A.XLSX');
    final choices = w.module.editorChoicesFor(a);
    expect(choices.map((c) => c.id), [ForgeZetaOfficeModule.choiceId]);
    expect(choices.single.label, 'ZetaOffice (web, comparison)');
    expect(w.module.handles(a), isTrue);
    expect(w.module.openUri(a), isFalse, reason: 'no default names it');
    choices.single.open(a);
    choices.single.open(a);
    expect(w.editorOf(a), isA<ForgeZetaOfficeEditor>());
    expect(w.shell.state.openEditors.where((e) => e.uri == a), hasLength(1));
    expect(
      (w.editorOf(a)! as ForgeZetaOfficeEditor).kind,
      ForgeZetaOfficeKind.spreadsheet,
    );
    expect(w.module.openUri(a), isTrue, reason: 'its editor is open');

    final b = await w.add('/docs/b.docx');
    w.shell.setFileTypeDefault('.docx', ForgeZetaOfficeModule.choiceId);
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgeZetaOfficeEditor>());

    final csv = await w.add('/docs/data.csv', 'a,b\n');
    expect(w.module.handles(csv), isFalse, reason: 'csv stays text');
    expect(w.module.editorChoicesFor(csv), hasLength(1));
    final txt = await w.add('/docs/notes.txt');
    expect(w.module.editorChoicesFor(txt), isEmpty);
    final remote = Uri.parse('https://example.org/x.docx');
    expect(w.module.openUri(remote), isFalse);
    expect(w.module.editorChoicesFor(remote), isEmpty);
    await w.close(tester);

    final only = ForgeZetaOfficeWorkspace(opensByDefault: true);
    final c = await only.add('/docs/c.pptx');
    expect(only.module.openUri(c), isTrue, reason: 'the only office route');
    expect(only.editorOf(c), isA<ForgeZetaOfficeEditor>());
    await only.close(tester);
  });

  testWidgets('FZO-ROUTE-1: the application\'s undo, redo and save reach '
      'ZetaOffice; its split copy says it cannot split', (tester) async {
    final w = ForgeZetaOfficeWorkspace();
    final a = await w.add('/docs/a.docx', 'original');
    w.module.editorChoicesFor(a).single.open(a);
    final editor = w.editorOf(a)! as ForgeZetaOfficeEditor;
    await w.show(tester, editor);
    final page = w.pages.last;
    expect(editor.controller.state, TomZetaOfficeState.open);
    expect(editor.isActionEnabled(_save), isTrue);
    page.edit(' typed');
    await tester.pump();
    expect(editor.isDirty.value, isTrue);
    expect(editor.isActionEnabled(_undo), isTrue);
    editor.executeAction(_undo);
    await tester.pumpAndSettle();
    expect(page.text, 'doc');
    expect(page.calls, contains('undo'));
    editor.executeAction(_redo);
    await tester.pumpAndSettle();
    expect(page.text, 'doc typed');
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(await w.text('/docs/a.docx'), 'doc typed');
    expect(editor.isDirty.value, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: editor.buildCopy)),
      ),
    );
    expect(find.text('This view cannot be split.'), findsOneWidget);
    await w.close(tester);
  });

  testWidgets('FZO-REOPEN-1: replaceContent answers false; a closed editor '
      'closes its page\'s site; the next open starts clean in the freed '
      'slot', (tester) async {
    final w = ForgeZetaOfficeWorkspace();
    final a = await w.add('/docs/a.docx');
    w.module.open(a);
    final zeta = w.editorOf(a)! as ForgeZetaOfficeEditor;
    await w.show(tester, zeta);
    expect(zeta.replaceContent('text'), isFalse);
    final serving = w.servings.last;
    expect(serving.serving, isTrue);
    await tester.pumpWidget(const SizedBox());
    await w.shell.editorHost.closeEditor(zeta);
    await tester.pumpAndSettle();
    expect(serving.serving, isFalse, reason: 'the page\'s site closed');
    expect(w.module.editors, isEmpty);
    w.module.open(a);
    final again = w.editorOf(a)! as ForgeZetaOfficeEditor;
    expect(identical(zeta, again), isFalse);
    await w.show(tester, again);
    expect(
      again.controller.state,
      TomZetaOfficeState.open,
      reason: 'the one-tab slot was freed',
    );
    expect(again.isActionEnabled(_undo), isFalse);
    await w.close(tester);
  });

  testWidgets('FZO-AVAIL-1: ZetaOffice is available with its files cached or '
      'the CDN answering, not offline without the cache', (tester) async {
    final cached = ForgeZetaOfficeWorkspace();
    expect(cached.module.available.value, isFalse, reason: 'not checked');
    await cached.module.checkAvailable();
    expect(cached.module.available.value, isTrue);
    await cached.close(tester);

    final online = ForgeZetaOfficeWorkspace(
      zetaFiles: FakeZetaOfficeFiles(state: TomZetaOfficeCacheState.missing),
    );
    await online.module.checkAvailable();
    expect(online.module.available.value, isTrue);
    await online.close(tester);

    final offline = ForgeZetaOfficeWorkspace(zetaFiles: _OfflineZetaFiles());
    await offline.module.checkAvailable();
    expect(offline.module.available.value, isFalse);
    await offline.close(tester);
  });
}

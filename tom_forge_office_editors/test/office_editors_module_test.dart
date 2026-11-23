/// The office editors in a Forge shell: the module opens the office files
/// itself (`.csv` only under Open With) in the default editor
/// (LibreOfficeKit) or the one the file-type default names, shows an editor
/// already open, offers both under Open With; the shell's save, undo, redo
/// and dirty reach the controllers; a closed editor ends its helper or page
/// and the next open starts clean; focus checks the file for outside
/// changes; without LibreOffice the tab shows detection's state panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_office_editors/tom_forge_office_editors.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultLayoutController, DefaultSystemState;
import 'package:tom_office_editor/testing.dart';
import 'package:tom_office_editor/tom_office_editor.dart';
import 'package:tom_office_editor/zetaoffice.dart';
import 'package:tom_office_protocol/tom_office_protocol.dart';

import 'support/workspace.dart';

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
  testWidgets('FOFF-OPEN-1: the office kinds (any case) open in the '
      'LibreOfficeKit editor, once; .csv, other files and files without a '
      'local path are not opened', (tester) async {
    final w = Workspace();
    final kinds = {
      '/docs/a.docx': ForgeOfficeKind.document,
      '/docs/B.XLSX': ForgeOfficeKind.spreadsheet,
      '/docs/c.pptx': ForgeOfficeKind.presentation,
      '/docs/d.odt': ForgeOfficeKind.document,
      '/docs/e.ods': ForgeOfficeKind.spreadsheet,
      '/docs/f.odp': ForgeOfficeKind.presentation,
      '/docs/g.doc': ForgeOfficeKind.document,
      '/docs/h.xls': ForgeOfficeKind.spreadsheet,
      '/docs/i.ppt': ForgeOfficeKind.presentation,
      '/docs/j.rtf': ForgeOfficeKind.document,
    };
    for (final entry in kinds.entries) {
      final uri = await w.add(entry.key);
      expect(w.module.handles(uri), isTrue, reason: entry.key);
      expect(w.module.openUri(uri), isTrue, reason: entry.key);
      final editor = w.editorOf(uri);
      expect(editor, isA<ForgeOfficeEditor>(), reason: entry.key);
      expect((editor! as ForgeOfficeEditor).kind, entry.value);
    }
    final a = w.fs.uriOf('/docs/a.docx');
    expect(w.module.openUri(a), isTrue);
    expect(
      w.shell.systemState.openEditors.where((e) => e.uri == a),
      hasLength(1),
    );

    final csv = await w.add('/docs/data.csv', 'a,b\n');
    expect(w.module.handles(csv), isFalse, reason: 'csv stays text');
    expect(w.module.openUri(csv), isFalse);
    expect(w.module.editorChoicesFor(csv).map((c) => c.id), [
      ForgeOfficeEditorsModule.lokChoiceId,
      ForgeOfficeEditorsModule.zetaOfficeChoiceId,
    ]);
    final txt = await w.add('/docs/notes.txt');
    expect(w.module.openUri(txt), isFalse);
    expect(w.module.editorChoicesFor(txt), isEmpty);
    final remote = Uri.parse('https://example.org/x.docx');
    expect(w.module.openUri(remote), isFalse);
    expect(w.module.editorChoicesFor(remote), isEmpty);

    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(find.byType(TomOfficeEditor), findsOneWidget);
    expect(editor.controller.state, TomOfficeEditorState.open);
    expect(editor.icon, Icons.description_outlined);
    expect(w.launcher!.documents, contains('/docs/a.docx'));
    await w.close(tester);
  });

  testWidgets('FOFF-CHOICE-1: Open With offers both editors; each choice '
      'opens its editor once, both may be open on one file; the file-type '
      'default picks the editor openUri opens', (tester) async {
    final w = Workspace();
    final a = await w.add('/docs/a.xlsx');
    final choices = w.module.editorChoicesFor(a);
    expect(choices.map((c) => c.id), [
      ForgeOfficeEditorsModule.lokChoiceId,
      ForgeOfficeEditorsModule.zetaOfficeChoiceId,
    ]);
    expect(choices.first.label, 'LibreOffice Calc (native)');
    expect(choices.last.label, 'ZetaOffice (web, comparison)');
    choices[1].open(a);
    expect(w.editorOf(a), isA<ForgeZetaOfficeEditor>());
    choices[1].open(a);
    choices[0].open(a);
    final open = w.shell.systemState.openEditors.where((e) => e.uri == a);
    expect(open.map((e) => e.runtimeType).toSet(), {
      ForgeZetaOfficeEditor,
      ForgeOfficeEditor,
    });
    expect(open, hasLength(2));

    final b = await w.add('/docs/b.docx');
    (w.shell.layout as DefaultLayoutController).setFileTypeDefaultEditor(
      'docx',
      ForgeOfficeEditorsModule.zetaOfficeChoiceId,
    );
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgeZetaOfficeEditor>());
    await w.close(tester);
  });

  testWidgets('FOFF-ROUTE-1: the shell\'s undo, redo and save reach '
      'LibreOffice; dirty and the state stream follow it', (tester) async {
    final w = Workspace();
    final a = await w.add('/docs/a.docx', 'original');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    final helper = w.helpers.last;
    final states = <void>[];
    final sub = editor.onStateChanged.listen(states.add);
    addTearDown(sub.cancel);
    expect(editor.getContent(), isNull);
    expect(editor.supportedActionIds, containsAll([_save, _undo, _redo]));
    expect(editor.isActionEnabled(_undo), isFalse);
    expect(editor.isDirty.value, isFalse);

    editor.controller.commitText(' typed');
    await tester.pump();
    expect(helper.text, 'doc typed');
    expect(editor.isDirty.value, isTrue);
    expect(editor.isActionEnabled(_undo), isTrue);
    expect(states, isNotEmpty);

    expect(editor.executeAction(_undo), isTrue);
    await tester.pump();
    expect(helper.text, 'doc');
    expect(helper.sentOf<OfficeUno>().last.command, '.uno:Undo');
    expect(editor.isActionEnabled(_redo), isTrue);
    editor.executeAction(_redo);
    await tester.pump();
    expect(helper.text, 'doc typed');

    // An explicit save goes to the editor, an automatic one does not.
    expect(
      saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic),
      isFalse,
    );
    expect(await w.text('/docs/a.docx'), 'original');
    expect(saveOwnedEditor(editor), isTrue);
    await tester.pumpAndSettle();
    expect(helper.saves, 1);
    expect(await w.text('/docs/a.docx'), 'doc typed');
    expect(editor.isDirty.value, isFalse);
    await w.close(tester);
  });

  testWidgets('FOFF-ROUTE-2: the shell\'s undo, redo and save reach '
      'ZetaOffice; its split copy says it cannot split', (tester) async {
    final w = Workspace();
    final a = await w.add('/docs/a.docx', 'original');
    w.module.editorChoicesFor(a).last.open(a);
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

  testWidgets('FOFF-REOPEN-1 / FZO-REOPEN-1: replaceContent answers false; '
      'a closed editor ends its helper or page; the next open starts clean '
      'with an empty history', (tester) async {
    final w = Workspace();
    final a = await w.add('/docs/a.docx');
    w.module.openUri(a);
    final first = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, first);
    first.controller.commitText('!');
    await tester.pump();
    expect(first.isDirty.value, isTrue);
    expect(first.replaceContent('text'), isFalse);
    await tester.pumpWidget(const SizedBox());
    w.shell.layout.closeEditor(first);
    await tester.pumpAndSettle();
    expect(w.module.editors, isEmpty);
    expect(w.helpers.last.sentOf<OfficeClose>(), hasLength(1));
    w.module.openUri(a);
    final second = w.editorOf(a)! as ForgeOfficeEditor;
    expect(identical(first, second), isFalse);
    await w.show(tester, second);
    expect(w.helpers, hasLength(2), reason: 'a new helper');
    expect(second.isDirty.value, isFalse);
    expect(second.isActionEnabled(_undo), isFalse);

    w.module.editorChoicesFor(a).last.open(a);
    final zeta = w.editorOf(a)! as ForgeZetaOfficeEditor;
    await w.show(tester, zeta);
    expect(zeta.replaceContent('text'), isFalse);
    final serving = w.servings.last;
    expect(serving.serving, isTrue);
    await tester.pumpWidget(const SizedBox());
    w.shell.layout.closeEditor(zeta);
    await tester.pumpAndSettle();
    expect(serving.serving, isFalse, reason: 'the page\'s site closed');
    w.module.editorChoicesFor(a).last.open(a);
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

  testWidgets('FOFF-FOCUS-1: when the window regains focus a clean editor '
      'reopens a file changed on disk', (tester) async {
    final w = Workspace();
    final a = await w.add('/docs/a.docx');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(w.helpers, hasLength(1));
    await w.fs.writeText(a, 'changed elsewhere');
    (w.shell.systemState as DefaultSystemState).setWindowFocused(true);
    await tester.pumpAndSettle();
    expect(w.helpers, hasLength(2), reason: 'reopened from disk');
    // The reload notice's toast runs out.
    await tester.pump(const Duration(seconds: 30));
    await w.close(tester);
  });

  testWidgets('FOFF-MISSING-1: without LibreOffice the tab shows the state '
      'panel with Open with ZetaOffice; Open With leaves office.lok out; '
      'Check again turns the panel into the editor in place', (tester) async {
    final w = Workspace(
      installation: const LibreOfficeInstallation(
        state: LibreOfficeState.missing,
      ),
    );
    final a = await w.add('/docs/a.docx');
    await w.module.detection;
    expect(w.module.openUri(a), isTrue);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(editor.controller.state, TomOfficeEditorState.unavailable);
    expect(
      find.byKey(const ValueKey('forge-office-missing-panel')),
      findsOneWidget,
    );
    expect(find.text('LibreOffice is not installed.'), findsOneWidget);
    expect(find.text('Download LibreOffice'), findsOneWidget);
    expect(find.text('Choose LibreOffice…'), findsOneWidget);
    expect(find.byKey(const ValueKey('office-check-again')), findsOneWidget);
    expect(find.text('Open with ZetaOffice'), findsOneWidget);
    expect(w.helpers, isEmpty, reason: 'no helper without LibreOffice');
    expect(w.module.editorChoicesFor(a).map((c) => c.id), [
      ForgeOfficeEditorsModule.zetaOfficeChoiceId,
    ]);
    // Open With on a file open in the panel shows that tab.
    expect(w.module.openUri(a), isTrue);
    expect(identical(w.editorOf(a), editor), isTrue);

    await tester.tap(find.text('Open with ZetaOffice'));
    await tester.pump();
    final zeta = w.shell.systemState.openEditors
        .whereType<ForgeZetaOfficeEditor>()
        .single;
    expect(zeta.uri, a);

    w.installation = foundLibreOffice;
    await tester.tap(find.byKey(const ValueKey('office-check-again')));
    await tester.pumpAndSettle();
    expect(w.detections, hasLength(2));
    expect(editor.controller.state, TomOfficeEditorState.open);
    expect(
      find.byKey(const ValueKey('forge-office-missing-panel')),
      findsNothing,
    );
    expect(find.byType(TomOfficeEditor), findsOneWidget);
    expect(
      identical(w.editorOf(a), editor) ||
          w.editorOf(a) is ForgeZetaOfficeEditor,
      isTrue,
    );
    expect(
      w.module.editorChoicesFor(a).map((c) => c.id),
      contains(ForgeOfficeEditorsModule.lokChoiceId),
    );
    await w.close(tester);
  });

  testWidgets('FOFF-MISSING-2: each state\'s panel; Choose LibreOffice… sets '
      'the path setting and detects with it; offline without the cache no '
      'ZetaOffice button', (tester) async {
    final w = Workspace(
      installation: const LibreOfficeInstallation(
        state: LibreOfficeState.damaged,
        bundlePath: '/Applications/LibreOffice.app',
        reason: 'codesign failed',
      ),
      zetaFiles: _OfflineZetaFiles(),
      userPath: '/Applications/LibreOffice.app',
    );
    expect(w.detections, [
      '/Applications/LibreOffice.app',
    ], reason: 'activation detects with the path setting');
    final a = await w.add('/docs/a.pptx');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(find.text('codesign failed'), findsOneWidget);
    expect(find.text('Download LibreOffice'), findsNothing);
    expect(
      find.text('Open with ZetaOffice'),
      findsNothing,
      reason: 'not cached and offline',
    );

    w.installation = const LibreOfficeInstallation(
      state: LibreOfficeState.quarantined,
      bundlePath: '/Users/me/Downloads/LibreOffice.app',
      version: kLibreOfficeMinimumVersion,
    );
    await tester.tap(find.byKey(const ValueKey('office-check-again')));
    await tester.pumpAndSettle();
    expect(find.text('Open LibreOffice'), findsOneWidget);

    w.installation = const LibreOfficeInstallation(
      state: LibreOfficeState.tooOld,
      bundlePath: '/Applications/LibreOffice.app',
      version: '24.2.7.2',
    );
    await w.module.checkAgain();
    await tester.pumpAndSettle();
    expect(
      find.text('LibreOffice 24.2.7.2 is older than 26.8.3.1.'),
      findsOneWidget,
    );

    w.picked = '/Applications/LibreOffice 26.app';
    w.installation = foundLibreOffice;
    await tester.tap(find.text('Choose LibreOffice…'));
    await tester.pumpAndSettle();
    expect(w.userPath, '/Applications/LibreOffice 26.app');
    expect(w.detections.last, '/Applications/LibreOffice 26.app');
    expect(editor.controller.state, TomOfficeEditorState.open);
    await w.close(tester);
  });

  testWidgets('FOFF-STATE-1: the part shown is kept and restored', (
    tester,
  ) async {
    final w = Workspace();
    final a = await w.add('/docs/a.docx');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    expect(editor.saveState(), isNull, reason: 'not open yet');
    editor.restoreState({'route': 'lok', 'part': 0});
    await w.show(tester, editor);
    expect(editor.saveState(), {'route': 'lok', 'part': 0});
    await w.close(tester);
  });
}

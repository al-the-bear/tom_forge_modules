/// The LibreOfficeKit module in a Forge shell (registered as a kit module):
/// it opens the office files itself (`.csv` only under Open With) in its
/// editor, unless the file-type default names the alternative route; shows
/// an editor already open; offers its editor under Open With; the
/// application's save, undo, redo and dirty reach the controller; a closed
/// editor ends its helper and the next open starts clean; focus checks the
/// file for outside changes; without LibreOffice the tab shows detection's
/// state panel with the alternative route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_forge_office_lok_testing/tom_forge_office_lok_testing.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

const _save = StandardEditingActions.saveActionId;
const _undo = StandardEditingActions.undoActionId;
const _redo = StandardEditingActions.redoActionId;

const _zeta = 'office.zetaoffice';

/// A route standing in for ZetaOffice: it records what it opens and checks.
class _Route {
  final opened = <Uri>[];
  final available = ValueNotifier(true);
  var checks = 0;

  ForgeOfficeAlternativeRoute get route => ForgeOfficeAlternativeRoute(
    choiceId: _zeta,
    label: 'Open with ZetaOffice',
    open: opened.add,
    available: available,
    check: () async => checks++,
  );
}

void main() {
  testWidgets('FOFF-OPEN-1: the office kinds (any case) open in the '
      'LibreOfficeKit editor, once; .csv, other files and files without a '
      'local path are not opened', (tester) async {
    final w = ForgeOfficeLokWorkspace();
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
    expect(w.shell.state.openEditors.where((e) => e.uri == a), hasLength(1));

    final csv = await w.add('/docs/data.csv', 'a,b\n');
    expect(w.module.handles(csv), isFalse, reason: 'csv stays text');
    expect(w.module.openUri(csv), isFalse);
    expect(w.module.editorChoicesFor(csv).map((c) => c.id), [
      ForgeOfficeLokModule.lokChoiceId,
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

  testWidgets('FOFF-CHOICE-1: Open With offers the LibreOfficeKit editor; '
      'its choice opens it once; a file-type default naming the alternative '
      'route leaves the file to it, without one wired LibreOfficeKit opens '
      'it', (tester) async {
    final route = _Route();
    final w = ForgeOfficeLokWorkspace(alternative: (_) => route.route);
    final a = await w.add('/docs/a.xlsx');
    final choices = w.module.editorChoicesFor(a);
    expect(choices.map((c) => c.id), [ForgeOfficeLokModule.lokChoiceId]);
    expect(choices.single.label, 'LibreOffice Calc (native)');
    choices.single.open(a);
    choices.single.open(a);
    expect(w.editorOf(a), isA<ForgeOfficeEditor>());
    expect(w.shell.state.openEditors.where((e) => e.uri == a), hasLength(1));

    final b = await w.add('/docs/b.docx');
    w.shell.setFileTypeDefault('.docx', _zeta);
    expect(w.module.openUri(b), isFalse, reason: 'left to the default');
    expect(w.editorOf(b), isNull);
    w.shell.setFileTypeDefault('.docx', ForgeOfficeLokModule.lokChoiceId);
    expect(w.module.openUri(b), isTrue);
    expect(w.editorOf(b), isA<ForgeOfficeEditor>());
    await w.close(tester);

    final alone = ForgeOfficeLokWorkspace();
    final c = await alone.add('/docs/c.docx');
    alone.shell.setFileTypeDefault('.docx', _zeta);
    expect(alone.module.openUri(c), isTrue, reason: 'no route to leave it to');
    expect(alone.editorOf(c), isA<ForgeOfficeEditor>());
    await alone.close(tester);
  });

  testWidgets('FOFF-ROUTE-1: the application\'s undo, redo and save reach '
      'LibreOffice; dirty and the state stream follow it', (tester) async {
    final w = ForgeOfficeLokWorkspace();
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

  testWidgets('FOFF-REOPEN-1: replaceContent answers false; a closed '
      'editor ends its helper; the next open starts clean with an empty '
      'history', (tester) async {
    final w = ForgeOfficeLokWorkspace();
    final a = await w.add('/docs/a.docx');
    w.module.openUri(a);
    final first = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, first);
    first.controller.commitText('!');
    await tester.pump();
    expect(first.isDirty.value, isTrue);
    expect(first.replaceContent('text'), isFalse);
    await tester.pumpWidget(const SizedBox());
    await w.shell.editorHost.closeEditor(first);
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
    await w.close(tester);
  });

  testWidgets('FOFF-FOCUS-1: when the window regains focus a clean editor '
      'reopens a file changed on disk', (tester) async {
    final w = ForgeOfficeLokWorkspace();
    final a = await w.add('/docs/a.docx');
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(w.helpers, hasLength(1));
    await w.fs.writeText(a, 'changed elsewhere');
    w.focusWindow();
    await tester.pumpAndSettle();
    expect(w.helpers, hasLength(2), reason: 'reopened from disk');
    // The reload notice's toast runs out.
    await tester.pump(const Duration(seconds: 30));
    await w.close(tester);
  });

  testWidgets('FOFF-MISSING-1: without LibreOffice the tab shows the state '
      'panel with the alternative route (Open with ZetaOffice); Open With '
      'leaves office.lok out; Check again turns the panel into the editor in '
      'place', (tester) async {
    final route = _Route();
    final w = ForgeOfficeLokWorkspace(
      installation: const LibreOfficeInstallation(
        state: LibreOfficeState.missing,
      ),
      alternative: (_) => route.route,
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
    expect(w.module.editorChoicesFor(a), isEmpty);
    expect(route.checks, greaterThan(0), reason: 'the route was checked');
    // Open With on a file open in the panel shows that tab.
    expect(w.module.openUri(a), isTrue);
    expect(identical(w.editorOf(a), editor), isTrue);

    await tester.tap(find.text('Open with ZetaOffice'));
    await tester.pump();
    expect(route.opened, [a]);

    w.installation = forgeOfficeFoundLibreOffice;
    await tester.tap(find.byKey(const ValueKey('office-check-again')));
    await tester.pumpAndSettle();
    expect(w.detections, hasLength(2));
    expect(editor.controller.state, TomOfficeEditorState.open);
    expect(
      find.byKey(const ValueKey('forge-office-missing-panel')),
      findsNothing,
    );
    expect(find.byType(TomOfficeEditor), findsOneWidget);
    expect(identical(w.editorOf(a), editor), isTrue);
    expect(
      w.module.editorChoicesFor(a).map((c) => c.id),
      contains(ForgeOfficeLokModule.lokChoiceId),
    );
    await w.close(tester);
  });

  testWidgets('FOFF-MISSING-2: each state\'s panel; Choose LibreOffice… sets '
      'the path setting and detects with it; Open LibreOffice opens the '
      'quarantined copy outside; an unavailable route has no button', (
    tester,
  ) async {
    final route = _Route()..available.value = false;
    final w = ForgeOfficeLokWorkspace(
      installation: const LibreOfficeInstallation(
        state: LibreOfficeState.damaged,
        bundlePath: '/Applications/LibreOffice.app',
        reason: 'codesign failed',
      ),
      userPath: '/Applications/LibreOffice.app',
      alternative: (_) => route.route,
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
      reason: 'the route is not available',
    );

    w.installation = const LibreOfficeInstallation(
      state: LibreOfficeState.quarantined,
      bundlePath: '/Users/me/Downloads/LibreOffice.app',
      version: kLibreOfficeMinimumVersion,
    );
    await tester.tap(find.byKey(const ValueKey('office-check-again')));
    await tester.pumpAndSettle();
    expect(find.text('Open LibreOffice'), findsOneWidget);
    await tester.tap(find.text('Open LibreOffice'));
    await tester.pump();
    expect(w.opened, [Uri.file('/Users/me/Downloads/LibreOffice.app')]);

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
    w.installation = forgeOfficeFoundLibreOffice;
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
    final w = ForgeOfficeLokWorkspace();
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

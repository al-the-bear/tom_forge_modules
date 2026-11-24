/// The two office routes in one shell, wired as Forge composes them: the
/// LibreOfficeKit module first, with the ZetaOffice module as its
/// alternative route (`ForgeOfficeAlternativeRoute`). Open With offers both,
/// LibreOfficeKit opens office files by default, a file-type default naming
/// ZetaOffice opens them there, an editor of either route already open is
/// shown, and without LibreOffice the state panel opens the file in
/// ZetaOffice — unless ZetaOffice is offline without its files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_lok_testing/adapter.dart';
import 'package:tom_forge_office_lok_testing/tom_forge_office_lok_testing.dart';
import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart';
import 'package:tom_forge_office_zetaoffice_testing/tom_forge_office_zetaoffice_testing.dart';
import 'package:tom_office_editor/testing.dart';
import 'package:tom_office_zetaoffice/testing.dart';
import 'package:tom_office_zetaoffice/tom_office_zetaoffice.dart';

/// ZetaOffice's files are not cached and the CDN does not answer.
class _OfflineZetaFiles extends FakeZetaOfficeFiles {
  _OfflineZetaFiles() : super(state: TomZetaOfficeCacheState.missing);

  @override
  Future<int> downloadSize() => Future.error(StateError('offline'));
}

/// The ZetaOffice workspace with the LibreOfficeKit module registered
/// before its module, ZetaOffice wired as its alternative route.
class _Both {
  _Both({
    LibreOfficeInstallation installation = forgeOfficeFoundLibreOffice,
    TomZetaOfficeFiles? zetaFiles,
  }) {
    w = ForgeZetaOfficeWorkspace(
      zetaFiles: zetaFiles,
      registerFirst: (w) {
        final zeta = w.module;
        lok = ForgeOfficeLokModule(
          files: w.files,
          detect: (_) async => installation,
          libreOfficePath: () => null,
          setLibreOfficePath: (_) async {},
          launcherFor: (found) => FakeOfficeHelperLauncher(
            installation: found,
            channelFor: () => ScriptedOfficeHelper('doc', fileSystem: w.fs),
          ),
          pickLibreOffice: () async => null,
          pickImage: () async => null,
          cleanUpHelpers: () async {},
          windowFocus: w.focus.stream,
          tileDecoder: forgeOfficeTestDecoder,
          alternative: ForgeOfficeAlternativeRoute(
            choiceId: ForgeZetaOfficeModule.choiceId,
            label: ForgeZetaOfficeModule.openLabel,
            open: zeta.open,
            editors: () => zeta.editors,
            available: zeta.available,
            check: zeta.checkAvailable,
          ),
        );
        w.shell.registerModule(lok);
      },
    );
  }

  late final ForgeZetaOfficeWorkspace w;
  late final ForgeOfficeLokModule lok;

  Future<void> close(WidgetTester tester) async {
    lok.deactivate();
    await w.close(tester);
  }
}

void main() {
  testWidgets('FOR-BOTH-1: Open With offers both routes, LibreOfficeKit '
      'first and the default; a default naming ZetaOffice opens the file '
      'there; an editor of either route already open is shown', (tester) async {
    final both = _Both();
    final w = both.w;
    final a = await w.add('/docs/a.docx');
    final ids = (await w.shell.editorPicker.choicesFor(
      ForgeContentItem(a),
    )).choices.map((c) => c.id).toList();
    expect(
      ids,
      containsAllInOrder([
        ForgeOfficeLokModule.lokChoiceId,
        ForgeZetaOfficeModule.choiceId,
      ]),
    );

    expect(await w.shell.openFile(a), isTrue);
    expect(w.editorOf(a), isA<ForgeOfficeEditor>());

    final b = await w.add('/docs/b.docx');
    w.shell.setFileTypeDefault('.docx', ForgeZetaOfficeModule.choiceId);
    expect(await w.shell.openFile(b), isTrue);
    expect(w.editorOf(b), isA<ForgeZetaOfficeEditor>());
    // LibreOfficeKit shows the ZetaOffice editor open on the file.
    w.shell.setFileTypeDefault('.docx', ForgeOfficeLokModule.lokChoiceId);
    expect(both.lok.openUri(b), isTrue);
    expect(w.shell.state.openEditors.where((e) => e.uri == b), hasLength(1));
    await both.close(tester);
  });

  testWidgets('FOR-BOTH-2: without LibreOffice the state panel opens the '
      'file in ZetaOffice; offline without its files the panel has no '
      'ZetaOffice button', (tester) async {
    const missing = LibreOfficeInstallation(state: LibreOfficeState.missing);
    final both = _Both(installation: missing);
    final w = both.w;
    final a = await w.add('/docs/a.docx');
    await both.lok.detection;
    expect(both.lok.openUri(a), isTrue);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(find.text('Open with ZetaOffice'), findsOneWidget);
    final ids = (await w.shell.editorPicker.choicesFor(
      ForgeContentItem(a),
    )).choices.map((c) => c.id);
    expect(ids, contains(ForgeZetaOfficeModule.choiceId));
    expect(ids, isNot(contains(ForgeOfficeLokModule.lokChoiceId)));
    await tester.tap(find.text('Open with ZetaOffice'));
    await tester.pump();
    expect(
      w.shell.state.openEditors.whereType<ForgeZetaOfficeEditor>().single.uri,
      a,
    );
    await both.close(tester);

    final offline = _Both(
      installation: missing,
      zetaFiles: _OfflineZetaFiles(),
    );
    final b = await offline.w.add('/docs/b.docx');
    await offline.lok.detection;
    offline.lok.openUri(b);
    await offline.w.show(tester, offline.w.editorOf(b)!);
    expect(
      find.byKey(const ValueKey('forge-office-missing-panel')),
      findsOneWidget,
    );
    expect(find.text('Open with ZetaOffice'), findsNothing);
    await offline.close(tester);
  });
}

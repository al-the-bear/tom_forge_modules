/// The office editors under Forge's undo conformance harness, with the
/// skips each route has (listed with their reasons in the README): the
/// LibreOfficeKit editor (LibreOffice's history, played by a scripted
/// helper) and the ZetaOffice editor (ZetaOffice's history, played by a
/// scripted page). The subjects and fakes are the test-support package's
/// (`tom_forge_office_editors_testing`), so an app composing the module runs
/// the same checks.
library;

import 'package:tom_forge_office_editors/tom_forge_office_editors.dart';
import 'package:tom_forge_office_editors_testing/tom_forge_office_editors_testing.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_office_editor/testing.dart';

void main() {
  runForgeUndoConformance('Office editor (LibreOfficeKit)', (saved) {
    final fs = forgeOfficeTestFileSystem(saved);
    final helper = ScriptedOfficeHelper(saved, fileSystem: fs);
    return ForgeOfficeEditorSubject(
      ForgeOfficeEditor(
        uri: forgeOfficeTestUri,
        host: forgeOfficeTestHost(
          fileSystem: fs,
          launcher: forgeOfficeTestLauncher(helper),
        ),
        kind: ForgeOfficeKind.document,
        decoder: forgeOfficeTestDecoder,
      ),
      helper,
    );
  }, skip: forgeOfficeEditorSkips);

  runForgeUndoConformance('ZetaOffice editor', (saved) {
    final serving = FakeZetaOfficeServing();
    final page = ScriptedZetaOfficePage(saved, serving);
    return ForgeZetaOfficeEditorSubject(
      ForgeZetaOfficeEditor(
        uri: forgeOfficeTestUri,
        host: forgeOfficeTestHost(fileSystem: forgeOfficeTestFileSystem(saved)),
        kind: ForgeOfficeKind.document,
        files: forgeZetaOfficeTestFiles(),
        serving: serving,
        channelForTesting: page,
      ),
      page,
    );
  }, skip: forgeZetaOfficeEditorSkips);
}

/// The ZetaOffice editor under Forge's undo conformance harness, with its
/// skips (listed with their reasons in the README): ZetaOffice's history,
/// played by a scripted page. The subject and fakes are the test-support
/// package's (`tom_forge_office_zetaoffice_testing`), so an app composing
/// the module runs the same checks.
library;

import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart';
import 'package:tom_forge_office_zetaoffice_testing/tom_forge_office_zetaoffice_testing.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_office_zetaoffice/testing.dart';

void main() {
  runForgeUndoConformance('ZetaOffice editor', (saved) {
    final serving = FakeZetaOfficeServing();
    final page = ScriptedZetaOfficePage(saved, serving);
    return ForgeZetaOfficeEditorSubject(
      ForgeZetaOfficeEditor(
        uri: forgeZetaOfficeTestUri,
        host: forgeZetaOfficeTestHost(
          fileSystem: forgeZetaOfficeTestFileSystem(saved),
        ),
        kind: ForgeZetaOfficeKind.document,
        files: forgeZetaOfficeTestFiles(),
        serving: serving,
        channelForTesting: page,
      ),
      page,
    );
  }, skip: forgeZetaOfficeEditorSkips);
}

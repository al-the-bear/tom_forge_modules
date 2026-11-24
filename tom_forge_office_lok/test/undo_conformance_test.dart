/// The LibreOfficeKit editor under Forge's undo conformance harness, with
/// its skips (listed with their reasons in the README): LibreOffice's
/// history, played by a scripted helper. The subject and fakes are the
/// test-support package's (`tom_forge_office_lok_testing`), so an app
/// composing the module runs the same checks.
library;

import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_forge_office_lok_testing/tom_forge_office_lok_testing.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

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
}

/// The YAML file kind's editor under Forge's undo conformance harness, with
/// no check skipped, twice: made by the kind as a file module makes it
/// (`ForgeFileKindTestBed`) and constructed directly; its controller keeps
/// the history over the source text, a save saves through the file's
/// session. The subject is the test support's
/// (`tom_forge_yaml_editor_testing`), so an app composing the kind runs the
/// same checks.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';
import 'package:tom_forge_yaml_editor_testing/tom_forge_yaml_editor_testing.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

void main() {
  setUp(() => kYamlEditorDebug = false);

  // The editor as the kind makes it (the way a file module opens the
  // file), and as an application that builds it itself makes it.
  runForgeUndoConformance('YAML file editor (kind)', (saved) {
    final bed = ForgeFileKindTestBed();
    return ForgeYamlFileSubject(
      bed.withText(forgeYamlFileKind, 'config.yaml', saved),
    );
  });
  runForgeUndoConformance('YAML file editor', (saved) {
    final bed = ForgeFileKindTestBed();
    return ForgeYamlFileSubject(
      ForgeYamlFileEditor(
        session: bed.sessionWithText('config.yaml', saved),
        module: bed.shellModule,
        api: bed.shell,
      ),
    );
  });
}

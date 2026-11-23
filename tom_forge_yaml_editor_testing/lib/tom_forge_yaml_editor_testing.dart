/// The YAML file kind's editor under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): how to drive
/// a [ForgeYamlFileEditor] the caller made, as a [ForgeUndoSubject] — the
/// adapter's suite builds it through the kind (`ForgeFileKindTestBed`), an
/// app's suite through the file module it composes, so both run the same
/// checks.
///
/// Test-only: a package of its own, taken as a dev_dependency by the suites
/// that drive the editor; nothing a product links depends on it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeFileSaveOutcome;
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

/// The YAML file editor, in its source view.
class ForgeYamlFileSubject extends ForgeUndoSubject {
  ForgeYamlFileSubject(this.editor) {
    editor.controller.textMode = true;
  }

  @override
  final ForgeYamlFileEditor editor;

  @override
  String textOf(WidgetTester tester) => editor.controller.sourceText;

  @override
  Future<void> saved() async {
    expect(await editor.file.save(), isNot(ForgeFileSaveOutcome.conflict));
  }
}

/// The website config editor under Forge's undo conformance harness
/// (`package:tom_forge_ui/testing.dart`): every document editor runs the same
/// six checks (`tom_forge/_agent_guidelines/editor_component_contract.md`
/// §2), in its YAML source view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart'
    show YamlEditorController, kYamlEditorDebug;

ForgeModule _module() => TomForgeShellModule()
  ..activate(
    DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Undo conformance',
      navigatorKey: GlobalKey<NavigatorState>(),
    ),
  );

class _Subject extends ForgeUndoSubject {
  _Subject(String saved)
    : editor = WebsiteConfigEditor(
        controller: YamlEditorController(initialYaml: saved)..textMode = true,
        module: _module(),
        onSaveReload: () async => true,
      );

  @override
  final WebsiteConfigEditor editor;
}

void main() {
  // The YAML editor's debug trail replaces FlutterError.onError, which a
  // failing widget test cannot survive.
  setUp(() => kYamlEditorDebug = false);

  runForgeUndoConformance('website config editor', _Subject.new);
}

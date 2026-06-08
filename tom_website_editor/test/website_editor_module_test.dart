// WebsiteEditorModule — the §6 in-shell config-editing surface.
//
// The config-editor decision (§7): there is NO bespoke form editor for
// `tom.website-editor.yaml`. The module contributes a [WebsiteConfigEditor]
// built on the standard [ForgeYamlEditor] (full YAML editing, folding, undo,
// save) and layers the config-specific diagnostics + save→reload on top. The
// diagnostics logic (schema agreement + placeholder awareness) is proven in
// config/website_config_diagnostics_test.dart; the editor's own recompute / self
// -load / reload hooks in website_config_editor_test.dart.
//
// These tests pin the missing link item §7 calls for: the module **forwards**
// those diagnostics into the shell's diagnostic manager, so editing the open
// config to something invalid (an invalid command) surfaces as a shell issue —
// the "invalid edits surface as issues" definition of done.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _validConfig = '''
version: 1
defaults:
  placeholders:
    repos: "/code"
websites:
  - id: ef
    paths:
      websiteRoot: "{repos}/ef"
    commands:
      build: "jaspr build"
''';

// A string `commands:` (must be a map) — the malformed-command case proven at
// the diagnostics layer by TWE-CFGDIAG-03.
const _invalidCommandConfig = '''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/a"
    commands: "jaspr build"
''';

final _configUri = Uri.parse('file:///tom.website-editor.yaml');

void main() {
  group('WebsiteEditorModule — config diagnostics forwarded to the shell', () {
    late DefaultShellApi shell;
    late WebsiteEditorModule module;

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {'/tom.website-editor.yaml': _validConfig},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      // Workspace root must be set before the module resolves the config URI
      // (mirrors main.dart's ordering).
      (shell.systemState as DefaultSystemState).setWorkspaceRootPath('/');
      module = WebsiteEditorModule();
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);
    });

    tearDown(() {
      module.deactivate();
      shell.dispose();
    });

    WebsiteConfigEditor configEditor() =>
        module.editors.single as WebsiteConfigEditor;

    test('TWE-MOD-01: a valid config leaves the shell free of config issues',
        () async {
      // Let the editor's self-load (configReader) settle.
      await Future<void>.delayed(Duration.zero);
      expect(configEditor().getContent(), contains('jaspr build'));
      expect(shell.diagnostics.forUri(_configUri), isEmpty);
    });

    test('TWE-MOD-02: editing to an invalid command surfaces a shell issue',
        () async {
      await Future<void>.delayed(Duration.zero);
      expect(shell.diagnostics.forUri(_configUri), isEmpty);

      // Edit the open config in-shell to a malformed `commands` value.
      configEditor().controller.setYaml(_invalidCommandConfig);

      final issues = shell.diagnostics.forUri(_configUri);
      expect(
        issues.any((d) =>
            d.severity == ForgeSeverity.error &&
            (d.code?.contains('commands') ?? false)),
        isTrue,
        reason: issues.toString(),
      );
    });

    test('TWE-MOD-03: fixing the config clears the shell issues again',
        () async {
      await Future<void>.delayed(Duration.zero);
      configEditor().controller.setYaml(_invalidCommandConfig);
      expect(shell.diagnostics.forUri(_configUri), isNotEmpty);

      // Repair the document — the forwarded set replaces the previous issues.
      configEditor().controller.setYaml(_validConfig);
      expect(shell.diagnostics.forUri(_configUri), isEmpty);
    });

    test('TWE-MOD-04: deactivate retracts the config issues from the shell',
        () async {
      await Future<void>.delayed(Duration.zero);
      configEditor().controller.setYaml(_invalidCommandConfig);
      expect(shell.diagnostics.forUri(_configUri), isNotEmpty);

      module.deactivate();
      expect(shell.diagnostics.forUri(_configUri), isEmpty);

      // Re-activate so tearDown's deactivate()/dispose() stay balanced.
      module = WebsiteEditorModule()..activate(shell);
    });
  });
}

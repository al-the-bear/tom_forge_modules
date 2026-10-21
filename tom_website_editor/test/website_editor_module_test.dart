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
import 'dart:async';

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

// A config with a content: block + a generateAll command, used to prove the
// refresh-after-generate wiring (§5): a control-panel generate run refreshes
// the content tree and structure explorer from disk without a manual reload.
const _contentConfig = '''
version: 1
defaults:
  shell: ["bash", "-lc"]
websites:
  - id: ef
    paths:
      websiteRoot: "/site"
    cwd: "{websiteRoot}"
    commands:
      generateAll: "dart run tool/gen_all.dart"
    content:
      dir: "{websiteRoot}/content"
''';

const _componentA = 'id: a\nname: A\ntagline: First\n';
const _componentB = 'id: b\nname: B\ntagline: Second\n';

/// A handle that replays [_lines] then completes with exit 0.
class _FakeHandle implements WebsiteProcessHandle {
  _FakeHandle(this._lines);
  final List<WebsiteProcessLine> _lines;

  @override
  Stream<WebsiteProcessLine> get output => Stream.fromIterable(_lines);

  @override
  Future<int> get exitCode => Future.value(0);

  @override
  Future<void> kill() async {}
}

/// Returns a [_FakeHandle] emitting [lines] then exit 0 for every spec.
class _FakeRunner implements WebsiteProcessRunner {
  _FakeRunner({this.lines = const []});
  final List<WebsiteProcessLine> lines;

  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) => _FakeHandle(lines);
}

/// Collects every file node's label in the structure tree (depth-first).
List<String> _fileLabels(List<StructureNode> nodes) => [
      for (final node in nodes) ...[
        if (node.kind == StructureNodeKind.file) node.label,
        ..._fileLabels(node.children),
      ],
    ];

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

  group('WebsiteEditorModule — refresh after a control-panel generate run', () {
    late DefaultShellApi shell;
    late WebsiteEditorModule module;
    late _FakeRunner runner;

    setUp(() async {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {
          '/tom.website-editor.yaml': _contentConfig,
          '/site/content/components/a.yaml': _componentA,
        },
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      (shell.systemState as DefaultSystemState).setWorkspaceRootPath('/');
      runner = _FakeRunner(lines: const [
        WebsiteProcessLine(ProcessStream.stdout, 'drift: 1 added, 0 removed'),
      ]);
      module = WebsiteEditorModule(runner: runner);
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);
      // Let the editor load + the content/structure trees do their first read.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    tearDown(() {
      module.deactivate();
      shell.dispose();
    });

    test('TWE-MOD-05: generateAll refreshes both trees from disk + logs drift',
        () async {
      // Baseline: only the seeded component is in the catalog/tree.
      expect(module.contentController!.components, hasLength(1));
      expect(_fileLabels(module.structureController!.nodes), contains('a.yaml'));
      expect(_fileLabels(module.structureController!.nodes),
          isNot(contains('b.yaml')));

      // The generator writes a new component file on disk...
      await shell.fileSystem
          .writeText(Uri.file('/site/content/components/b.yaml'), _componentB);

      // ...and the user runs the generate command from the control panel.
      final code = await module.controlController!.runCommand('generateAll');
      expect(code, 0);

      // The refresh-after-generate seam re-reads disk (both refreshes are
      // fire-and-forget, so let them settle).
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(module.contentController!.components, hasLength(2));
      expect(_fileLabels(module.structureController!.nodes), contains('b.yaml'));
      // The raw generator drift output is surfaced verbatim in the control log.
      expect(
        module.controlController!.log
            .any((e) => e.message.contains('drift: 1 added')),
        isTrue,
      );
    });
  });
}

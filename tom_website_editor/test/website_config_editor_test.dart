// WebsiteConfigEditor — the §6 first-class editor for tom.website-editor.yaml.
//
// The diagnostics logic is proven in config/website_config_diagnostics_test.dart;
// these tests cover the editor's added behaviour: routing (canHandle), the
// one-time self-load (module editors are not handed file content by the shell),
// diagnostics recompute on edit, and the save → reload hook.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

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

final _configUri = Uri.parse('file:///ws/tom.website-editor.yaml');

/// Minimal non-shell module so the editor skips shell integration paths.
class _FakeModule extends ForgeModule {
  @override
  String get displayName => 'fake';
  @override
  void activate(ForgeShellApi shell) {}
  @override
  void deactivate() {}
  @override
  List<ForgeEditor> get editors => const [];
  @override
  List<ForgeView> get views => const [];
  @override
  List<ForgeAction> get actions => const [];
  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

WebsiteConfigEditor _editor({
  String initialYaml = '',
  Future<String> Function()? configReader,
  Future<bool> Function()? onSaveReload,
  Map<String, String> builtins = const {},
}) {
  return WebsiteConfigEditor(
    controller: YamlEditorController(initialYaml: initialYaml, uri: _configUri),
    module: _FakeModule(),
    onSaveReload: onSaveReload ?? () async => true,
    configReader: configReader,
    builtins: builtins,
  );
}

void main() {
  group('WebsiteConfigEditor — routing', () {
    test('TWE-CFGED-01: accepts the configured filename', () {
      final editor = _editor(initialYaml: _validConfig);
      expect(editor.canHandle(_configUri), FileHandlingResult.accept);
      editor.dispose();
    });

    test('TWE-CFGED-02: does not accept other YAML files', () {
      final editor = _editor(initialYaml: _validConfig);
      expect(
        editor.canHandle(Uri.parse('file:///ws/pubspec.yaml')),
        FileHandlingResult.inspect,
      );
      editor.dispose();
    });
  });

  group('WebsiteConfigEditor — self-load', () {
    test('TWE-CFGED-03: loads on-disk content and starts clean', () async {
      var reads = 0;
      final editor = _editor(configReader: () async {
        reads++;
        return _validConfig;
      });
      // The self-load is async; let it settle.
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      expect(editor.getContent(), contains('jaspr build'));
      expect(editor.isDirty.value, isFalse);
      editor.dispose();
    });

    test('TWE-CFGED-04: a read failure leaves an empty, clean document',
        () async {
      final editor = _editor(
        configReader: () async => throw Exception('missing'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(editor.getContent(), isEmpty);
      expect(editor.isDirty.value, isFalse);
      editor.dispose();
    });
  });

  group('WebsiteConfigEditor — diagnostics', () {
    test('TWE-CFGED-05: a valid document yields no diagnostics', () {
      final editor = _editor(initialYaml: _validConfig);
      expect(editor.configDiagnostics.value, isEmpty);
      editor.dispose();
    });

    test('TWE-CFGED-06: editing to an invalid document surfaces errors',
        () async {
      final editor = _editor(initialYaml: _validConfig);
      expect(editor.configDiagnostics.value, isEmpty);

      var notified = false;
      editor.configDiagnostics.addListener(() => notified = true);
      editor.controller.setYaml('websites: []\n');

      expect(notified, isTrue);
      expect(
        editor.configDiagnostics.value
            .any((d) => d.severity == ForgeSeverity.error),
        isTrue,
      );
      editor.dispose();
    });

    test('TWE-CFGED-07: an unknown placeholder surfaces as a warning', () {
      final editor = _editor(initialYaml: '''
version: 1
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
    commands:
      build: "jaspr build {nope}"
''');
      expect(
        editor.configDiagnostics.value
            .any((d) => d.severity == ForgeSeverity.warning),
        isTrue,
      );
      editor.dispose();
    });
  });

  group('WebsiteConfigEditor — save → reload', () {
    test('TWE-CFGED-08: markClean triggers the reload hook', () async {
      var reloads = 0;
      final editor = _editor(
        initialYaml: _validConfig,
        onSaveReload: () async {
          reloads++;
          return true;
        },
      );
      editor.markClean();
      await Future<void>.delayed(Duration.zero);
      expect(reloads, 1);
      expect(editor.isDirty.value, isFalse);
      editor.dispose();
    });

    test('TWE-CFGED-09: the self-load does not trigger a reload', () async {
      var reloads = 0;
      final editor = _editor(
        configReader: () async => _validConfig,
        onSaveReload: () async {
          reloads++;
          return true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      // Self-load marks the controller clean directly, not via editor.markClean.
      expect(reloads, 0);
      editor.dispose();
    });
  });
}

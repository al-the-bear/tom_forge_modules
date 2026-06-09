// Config loading + validation — §2 of the tom_website_editor specification.
import 'dart:io';

import 'package:tom_website_editor_core/tom_website_editor_core.dart';
import 'package:test/test.dart';

/// The canonical, hand-verified sample committed in the quest folder.
/// Resolved relative to the package root (the cwd `dart test` runs from).
const _canonicalSamplePath =
    '../../_ai/quests/tom_forge/tom.website-editor.sample.yaml';

void main() {
  group('loadWebsiteEditorConfig — valid configs', () {
    test('TWEC-CFG-01: accepts the canonical sample', () {
      final file = File(_canonicalSamplePath);
      expect(file.existsSync(), isTrue,
          reason: 'canonical sample not found at $_canonicalSamplePath');
      final result = loadWebsiteEditorConfig(file.readAsStringSync());
      expect(result.isValid, isTrue, reason: result.issues.toString());
      expect(result.config, isNotNull);
    });

    test('TWEC-CFG-02: parses the model fields', () {
      final result = loadWebsiteEditorConfig('''
version: 1
defaults:
  shell: ["bash", "-lc"]
  placeholders:
    port: "8080"
websites:
  - id: ef
    label: "Enterprise Flutter"
    paths:
      websiteRoot: "/code/ef/website"
    preview:
      devUrl: "http://localhost:{port}"
    cwd: "{websiteRoot}"
    commands:
      build: "jaspr build"
''');
      expect(result.isValid, isTrue, reason: result.issues.toString());
      final config = result.config!;
      expect(config.version, 1);
      expect(config.defaults.shell, ['bash', '-lc']);
      expect(config.defaults.placeholders['port'], '8080');
      expect(config.websites, hasLength(1));
      final site = config.websites.first;
      expect(site.id, 'ef');
      expect(site.label, 'Enterprise Flutter');
      expect(site.paths['websiteRoot'], '/code/ef/website');
      expect(site.preview['devUrl'], 'http://localhost:{port}');
      expect(site.cwd, '{websiteRoot}');
      expect(site.commands['build'], 'jaspr build');
      expect(config.websiteById('ef'), isNotNull);
      expect(config.websiteById('missing'), isNull);
    });

    test('TWEC-CFG-03: defaults.shell falls back to [bash, -lc]', () {
      final result = loadWebsiteEditorConfig('''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef"
''');
      expect(result.isValid, isTrue, reason: result.issues.toString());
      expect(result.config!.defaults.shell, ['bash', '-lc']);
    });

    test('TWEC-CFG-12: the canonical sample editableFields match the code default',
        () {
      // Single source of truth: the sample's curated content fields must equal
      // the package default `kDefaultEditableFields`, which the spec §2 sample
      // and §6a prose mirror. This guards the §11 reconciliation against drift.
      final file = File(_canonicalSamplePath);
      final result = loadWebsiteEditorConfig(file.readAsStringSync());
      final content = result.config!.websites.first.content;
      expect(content, isNotNull,
          reason: 'the canonical sample must declare a content: block');
      expect(content!.editableFields, kDefaultEditableFields,
          reason: 'sample editableFields must equal the canonical default');
      // The canonical list is the unsuffixed §16 copy-file front-matter keys
      // (overview lives in the body, not an `overview-md` key) — forge web todo 14.
      expect(content.editableFields, ['tagline', 'summary', 'enables']);
    });
  });

  group('loadWebsiteEditorConfig — rejects malformed configs', () {
    void expectRejected(String yaml, String pathFragment) {
      final result = loadWebsiteEditorConfig(yaml);
      expect(result.isValid, isFalse, reason: 'expected rejection for: $yaml');
      expect(result.config, isNull);
      expect(
        result.issues.any((i) =>
            i.severity == ConfigSeverity.error &&
            i.path.contains(pathFragment)),
        isTrue,
        reason: 'no error mentioning "$pathFragment" in ${result.issues}',
      );
    }

    test('TWEC-CFG-04: missing required key (version)', () {
      expectRejected('''
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef"
''', 'version');
    });

    test('TWEC-CFG-05: wrong type (version as string)', () {
      expectRejected('''
version: "1"
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef"
''', 'version');
    });

    test('TWEC-CFG-06: malformed commands (string, not a map)', () {
      expectRejected('''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef"
    commands: "jaspr build"
''', 'commands');
    });

    test('TWEC-CFG-07: malformed paths (missing websiteRoot)', () {
      expectRejected('''
version: 1
websites:
  - id: ef
    paths:
      designDir: "/code/ef/design"
''', 'websiteRoot');
    });

    test('TWEC-CFG-08: empty websites list', () {
      expectRejected('''
version: 1
websites: []
''', 'websites');
    });

    test('TWEC-CFG-09: unknown top-level key is rejected (typo guard)', () {
      expectRejected('''
version: 1
websytes: []
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef"
''', 'websytes');
    });

    test('TWEC-CFG-10: invalid YAML surfaces as an error, not an exception', () {
      final result = loadWebsiteEditorConfig('version: 1\n  bad: : :');
      expect(result.isValid, isFalse);
      expect(result.config, isNull);
    });
  });

  group('semantic validation', () {
    test('TWEC-CFG-11: duplicate website ids are an error', () {
      final result = loadWebsiteEditorConfig('''
version: 1
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
  - id: ef
    paths: { websiteRoot: "/b" }
''');
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.message.toLowerCase().contains('duplicate')),
        isTrue,
        reason: result.issues.toString(),
      );
    });
  });
}

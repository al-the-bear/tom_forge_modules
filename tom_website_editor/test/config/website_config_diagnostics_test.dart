// websiteConfigDiagnostics — the schema + placeholder diagnostics the §6
// WebsiteConfigEditor surfaces.
//
// This is the heart of the config editor and is pure (no Flutter shell), so it
// is tested directly here: it must agree with the runtime loader on validity
// (single source of truth) and flag unresolvable placeholders as warnings.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

final _uri = Uri.parse('file:///ws/tom.website-editor.yaml');

List<ForgeDiagnostic> _diags(String yaml,
        {Map<String, String> builtins = const {}}) =>
    websiteConfigDiagnostics(yamlText: yaml, uri: _uri, builtins: builtins);

void main() {
  group('websiteConfigDiagnostics — schema agreement', () {
    test('TWE-CFGDIAG-01: a valid config produces no diagnostics', () {
      final diags = _diags('''
version: 1
defaults:
  placeholders:
    repos: "/code"
websites:
  - id: ef
    paths:
      websiteRoot: "{repos}/ef/website"
      builtDir: "{websiteRoot}/build"
    preview:
      devUrl: "http://localhost:{port}"
    commands:
      build: "jaspr build"
''', builtins: {'port': '8080'});
      expect(diags, isEmpty);
    });

    test('TWE-CFGDIAG-02: missing version is an error diagnostic', () {
      final diags = _diags('''
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
''');
      expect(diags.any((d) => d.severity == ForgeSeverity.error), isTrue);
      expect(diags.every((d) => d.source == websiteConfigDiagnosticSource),
          isTrue);
      expect(diags.any((d) => d.code == 'version'), isTrue);
    });

    test('TWE-CFGDIAG-03: malformed commands is an error diagnostic', () {
      final diags = _diags('''
version: 1
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
    commands: "jaspr build"
''');
      expect(
        diags.any((d) =>
            d.severity == ForgeSeverity.error &&
            (d.code?.contains('commands') ?? false)),
        isTrue,
        reason: diags.toString(),
      );
    });

    test('TWE-CFGDIAG-04: malformed paths (no websiteRoot) is an error', () {
      final diags = _diags('''
version: 1
websites:
  - id: ef
    paths: { designDir: "/a/design" }
''');
      expect(
        diags.any((d) => d.severity == ForgeSeverity.error),
        isTrue,
        reason: diags.toString(),
      );
    });
  });

  group('websiteConfigDiagnostics — placeholder awareness', () {
    test('TWE-CFGDIAG-05: an unknown placeholder in a command is a warning', () {
      final diags = _diags('''
version: 1
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
    commands:
      build: "jaspr build --out {nope}"
''');
      final warnings =
          diags.where((d) => d.severity == ForgeSeverity.warning).toList();
      expect(warnings, isNotEmpty);
      expect(warnings.any((d) => d.message.contains('nope')), isTrue,
          reason: diags.toString());
      expect(warnings.any((d) => d.code == 'websites[0].commands.build'),
          isTrue);
    });

    test('TWE-CFGDIAG-06: a resolvable placeholder produces no warning', () {
      final diags = _diags('''
version: 1
defaults:
  placeholders:
    repos: "/code"
websites:
  - id: ef
    paths:
      websiteRoot: "{repos}/ef"
    commands:
      build: "jaspr build {websiteRoot}"
''');
      expect(diags, isEmpty);
    });

    test('TWE-CFGDIAG-07: a built-in placeholder is honoured (no warning)', () {
      final diags = _diags('''
version: 1
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
    preview:
      devUrl: "http://localhost:{port}"
''', builtins: {'port': '8080'});
      expect(diags, isEmpty);
    });

    test('TWE-CFGDIAG-08: no placeholder warnings when the config is invalid',
        () {
      // Structurally invalid → only structural errors, no placeholder noise.
      final diags = _diags('''
websites:
  - id: ef
    paths: { websiteRoot: "{nope}" }
''');
      expect(diags.every((d) => d.severity == ForgeSeverity.error), isTrue,
          reason: diags.toString());
    });
  });
}

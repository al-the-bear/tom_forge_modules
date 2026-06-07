// WebsiteRegistry — the load/select/reload backbone of §9.2.
//
// Covers building the registry from config, active-website selection, and the
// reload contract: a valid reload replaces the config (preserving the active
// selection when it still exists), an invalid reload is rejected and the
// last-good registry stays active (§6 "Save → reload").
import 'package:tom_website_editor_core/tom_website_editor_core.dart';
import 'package:test/test.dart';

const _twoSites = '''
version: 1
websites:
  - id: alpha
    paths: { websiteRoot: "/a" }
  - id: beta
    paths: { websiteRoot: "/b" }
''';

void main() {
  group('WebsiteRegistry.load', () {
    test('TWEC-REG-01: builds from a valid config; active defaults to first',
        () {
      final load = WebsiteRegistry.load(_twoSites);
      expect(load.isValid, isTrue, reason: load.issues.toString());
      final registry = load.registry!;
      expect(registry.websites.map((w) => w.id), ['alpha', 'beta']);
      expect(registry.activeWebsiteId, 'alpha');
      expect(registry.activeWebsite.paths['websiteRoot'], '/a');
    });

    test('TWEC-REG-02: invalid config yields no registry + issues', () {
      final load = WebsiteRegistry.load('version: 2\nwebsites: []\n');
      expect(load.isValid, isFalse);
      expect(load.registry, isNull);
      expect(load.issues.any((i) => i.severity == ConfigSeverity.error),
          isTrue);
    });
  });

  group('WebsiteRegistry.selectWebsite', () {
    test('TWEC-REG-03: selecting a known id changes the active website', () {
      final registry = WebsiteRegistry.load(_twoSites).registry!;
      registry.selectWebsite('beta');
      expect(registry.activeWebsiteId, 'beta');
      expect(registry.activeWebsite.paths['websiteRoot'], '/b');
    });

    test('TWEC-REG-04: selecting an unknown id throws and leaves active intact',
        () {
      final registry = WebsiteRegistry.load(_twoSites).registry!;
      expect(() => registry.selectWebsite('ghost'), throwsArgumentError);
      expect(registry.activeWebsiteId, 'alpha');
    });
  });

  group('WebsiteRegistry.reload', () {
    test('TWEC-REG-05: valid reload replaces config, preserves active id', () {
      final registry = WebsiteRegistry.load(_twoSites).registry!;
      registry.selectWebsite('beta');
      final outcome = registry.reload('''
version: 1
websites:
  - id: alpha
    paths: { websiteRoot: "/a2" }
  - id: beta
    paths: { websiteRoot: "/b2" }
''');
      expect(outcome.applied, isTrue);
      expect(registry.activeWebsiteId, 'beta');
      expect(registry.activeWebsite.paths['websiteRoot'], '/b2');
    });

    test('TWEC-REG-06: valid reload that drops the active id resets to first',
        () {
      final registry = WebsiteRegistry.load(_twoSites).registry!;
      registry.selectWebsite('beta');
      final outcome = registry.reload('''
version: 1
websites:
  - id: gamma
    paths: { websiteRoot: "/g" }
''');
      expect(outcome.applied, isTrue);
      expect(registry.activeWebsiteId, 'gamma');
    });

    test('TWEC-REG-07: invalid reload is rejected; last-good registry stays',
        () {
      final registry = WebsiteRegistry.load(_twoSites).registry!;
      registry.selectWebsite('beta');
      final outcome = registry.reload('version: 1\nwebsites: []\n');
      expect(outcome.applied, isFalse);
      expect(outcome.issues.any((i) => i.severity == ConfigSeverity.error),
          isTrue);
      // last-good preserved
      expect(registry.websites.map((w) => w.id), ['alpha', 'beta']);
      expect(registry.activeWebsiteId, 'beta');
    });
  });
}

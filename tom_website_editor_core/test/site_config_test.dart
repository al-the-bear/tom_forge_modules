// SiteConfig (§9 todo 4): a structured, validated view of a website's
// `content/site.yaml`. The home page's `featured` component is optional —
// an empty `home.featured:` means "no featured component" (the components
// page renders the flat grid) and must validate green, not error.
import 'package:tom_website_editor_core/tom_website_editor_core.dart';
import 'package:test/test.dart';

void main() {
  group('TWE-SITE-01: parse home.featured', () {
    test('an empty featured loads as no-featured but keeps its source line', () {
      const raw = '''
title: Tom Framework
home:
  hero-md: |
    # Hi
  featured:
''';
      final config = SiteConfig.parse(raw);
      expect(config.title, 'Tom Framework');
      expect(config.hasFeatured, isFalse);
      expect(config.featured, isNull);
      // The key exists (so the editor can set a value) — line 4 (0-based).
      expect(config.featuredSourceLine, 4);
    });

    test('a set featured loads as the component id', () {
      const raw = '''
title: Tom Framework
home:
  featured: d4rt
''';
      final config = SiteConfig.parse(raw);
      expect(config.hasFeatured, isTrue);
      expect(config.featured, 'd4rt');
      expect(config.featuredSourceLine, 2);
    });

    test('an absent home block loads with no featured and no source line', () {
      const raw = 'title: Tom Framework\n';
      final config = SiteConfig.parse(raw);
      expect(config.hasFeatured, isFalse);
      expect(config.featured, isNull);
      expect(config.featuredSourceLine, isNull);
    });
  });

  group('TWE-SITE-02: validate home.featured (optional/empty-valued)', () {
    test('an empty featured validates green', () {
      final result = loadSiteConfig('''
title: Tom Framework
home:
  featured:
''');
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
      expect(result.config, isNotNull);
      expect(result.config!.hasFeatured, isFalse);
    });

    test('an absent featured validates green', () {
      final result = loadSiteConfig('title: Tom Framework\nhome: {}\n');
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('a featured matching a known component validates green', () {
      final result = loadSiteConfig(
        'home:\n  featured: d4rt\n',
        knownComponentIds: const {'d4rt', 'basics'},
      );
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('a featured referencing an unknown component is a warning, not error',
        () {
      final result = loadSiteConfig(
        'home:\n  featured: ghost\n',
        knownComponentIds: const {'d4rt', 'basics'},
      );
      // Still loads (valid) — an unknown id is a non-fatal warning.
      expect(result.isValid, isTrue);
      expect(result.issues, hasLength(1));
      expect(result.issues.single.severity, ConfigSeverity.warning);
      expect(result.issues.single.path, 'home.featured');
    });

    test('a non-mapping home is an error', () {
      final result = loadSiteConfig('home: nope\n');
      expect(result.isValid, isFalse);
      expect(result.issues.single.path, 'home');
    });

    test('invalid YAML is reported, not thrown', () {
      final result = loadSiteConfig('title: : :\n');
      expect(result.isValid, isFalse);
      expect(result.config, isNull);
    });
  });

  group('TWE-SITE-03: parse detailedComponents (editor §9 item 7)', () {
    test('a present list loads its ids and the key source line', () {
      const raw = '''
title: Tom Framework
detailedComponents: [d4rt, basics]
''';
      final config = SiteConfig.parse(raw);
      expect(config.detailedComponents, ['d4rt', 'basics']);
      expect(config.hasDetailedComponents, isTrue);
      // The key is on line 1 (0-based) — drives a line-precise edit.
      expect(config.detailedComponentsSourceLine, 1);
    });

    test('an absent key loads as null with no source line', () {
      const raw = 'title: Tom Framework\n';
      final config = SiteConfig.parse(raw);
      // null is "key absent" → the website falls back to its built-in default.
      expect(config.detailedComponents, isNull);
      expect(config.hasDetailedComponents, isFalse);
      expect(config.detailedComponentsSourceLine, isNull);
    });

    test('an explicit empty list is an empty list, not null', () {
      const raw = 'title: Tom Framework\ndetailedComponents: []\n';
      final config = SiteConfig.parse(raw);
      // An explicit (empty) list overrides the default → "no detailed
      // components", distinct from the absent key above.
      expect(config.detailedComponents, isEmpty);
      expect(config.detailedComponents, isNotNull);
      expect(config.hasDetailedComponents, isTrue);
      expect(config.detailedComponentsSourceLine, 1);
    });
  });

  group('TWE-SITE-04: validate detailedComponents (editor §9 item 7)', () {
    test('an absent key validates green', () {
      final result = loadSiteConfig(
        'title: Tom Framework\n',
        knownComponentIds: const {'d4rt', 'basics'},
      );
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('a list of known ids validates green', () {
      final result = loadSiteConfig(
        'detailedComponents: [d4rt, basics]\n',
        knownComponentIds: const {'d4rt', 'basics'},
      );
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('an empty list validates green', () {
      final result = loadSiteConfig(
        'detailedComponents: []\n',
        knownComponentIds: const {'d4rt', 'basics'},
      );
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('an unknown id is a warning at path detailedComponents, not an error',
        () {
      final result = loadSiteConfig(
        'detailedComponents: [d4rt, ghost]\n',
        knownComponentIds: const {'d4rt', 'basics'},
      );
      // Still loads (valid) — an unknown id is a non-fatal warning.
      expect(result.isValid, isTrue);
      expect(result.issues, hasLength(1));
      expect(result.issues.single.severity, ConfigSeverity.warning);
      expect(result.issues.single.path, 'detailedComponents');
    });

    test('a non-list detailedComponents is an error', () {
      final result = loadSiteConfig('detailedComponents: nope\n');
      expect(result.isValid, isFalse);
      expect(result.issues.single.path, 'detailedComponents');
    });
  });
}

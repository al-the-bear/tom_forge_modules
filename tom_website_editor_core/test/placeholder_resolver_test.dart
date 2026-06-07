// PlaceholderResolver — §3 of the tom_website_editor specification.
//
// Covers resolution priority, recursion, cycle detection, max depth,
// unknown-placeholder errors, `{env:VAR}`, `~`/`{home}`, and `{date}`/`{time}`.
import 'package:tom_website_editor_core/tom_website_editor_core.dart';
import 'package:test/test.dart';

void main() {
  group('PlaceholderResolver — resolution priority', () {
    test('TWEC-RES-01: per-website key wins over defaults and built-ins', () {
      final resolver = PlaceholderResolver(
        websiteScope: {'port': 'website-port'},
        defaults: {'port': 'defaults-port'},
        builtins: {'port': 'builtin-port'},
        homeDir: '/home/test',
      );
      expect(resolver.resolve('{port}'), 'website-port');
    });

    test('TWEC-RES-02: defaults win over built-ins', () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {'port': 'defaults-port'},
        builtins: {'port': 'builtin-port'},
        homeDir: '/home/test',
      );
      expect(resolver.resolve('{port}'), 'defaults-port');
    });

    test('TWEC-RES-03: built-in used when neither override defines it', () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {},
        builtins: {'browser': 'open'},
        homeDir: '/home/test',
      );
      expect(resolver.resolve('{browser}'), 'open');
    });
  });

  group('PlaceholderResolver — recursion', () {
    test('TWEC-RES-04: a placeholder expands to a string with more placeholders',
        () {
      final resolver = PlaceholderResolver(
        websiteScope: {
          'websiteRoot': '{repos}/enterprise_flutter/website',
          'builtDir': '{websiteRoot}/build/jaspr',
        },
        defaults: {'repos': '/code/second_wind'},
        homeDir: '/home/test',
      );
      expect(
        resolver.resolve('{builtDir}'),
        '/code/second_wind/enterprise_flutter/website/build/jaspr',
      );
    });

    test('TWEC-RES-05: leading ~ in a resolved value expands to home', () {
      final resolver = PlaceholderResolver(
        websiteScope: {'websiteRoot': '{repos}/ef'},
        defaults: {'repos': '~/Desktop/code'},
        homeDir: '/Users/test',
      );
      expect(resolver.resolve('{websiteRoot}'), '/Users/test/Desktop/code/ef');
    });
  });

  group('PlaceholderResolver — errors', () {
    test('TWEC-RES-06: cycle detection throws, does not hang', () {
      final resolver = PlaceholderResolver(
        websiteScope: {'a': '{b}', 'b': '{a}'},
        defaults: {},
        homeDir: '/home/test',
      );
      expect(
        () => resolver.resolve('{a}'),
        throwsA(isA<PlaceholderException>()
            .having((e) => e.message, 'message', contains('cycle'))),
      );
    });

    test('TWEC-RES-07: max depth guard throws', () {
      // Self-referential chain longer than maxDepth without a 2-node cycle.
      final scope = <String, String>{};
      for (var i = 0; i < 100; i++) {
        scope['k$i'] = '{k${i + 1}}';
      }
      scope['k100'] = 'leaf';
      final resolver = PlaceholderResolver(
        websiteScope: scope,
        defaults: {},
        homeDir: '/home/test',
        maxDepth: 8,
      );
      expect(
        () => resolver.resolve('{k0}'),
        throwsA(isA<PlaceholderException>()
            .having((e) => e.message, 'message', contains('depth'))),
      );
    });

    test('TWEC-RES-08: unknown placeholder is an error carrying token + location',
        () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {},
        homeDir: '/home/test',
      );
      expect(
        () => resolver.resolve('{nope}', location: 'websites[0].cwd'),
        throwsA(isA<PlaceholderException>()
            .having((e) => e.token, 'token', 'nope')
            .having((e) => e.location, 'location', 'websites[0].cwd')),
      );
    });
  });

  group('PlaceholderResolver — built-ins', () {
    test('TWEC-RES-09: {env:VAR} resolves from the injected environment', () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {},
        environment: {'MY_TOKEN': 'abc123'},
        homeDir: '/home/test',
      );
      expect(resolver.resolve('prefix-{env:MY_TOKEN}'), 'prefix-abc123');
    });

    test('TWEC-RES-10: {env:VAR} unset is an error', () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {},
        environment: {},
        homeDir: '/home/test',
      );
      expect(
        () => resolver.resolve('{env:MISSING}'),
        throwsA(isA<PlaceholderException>()
            .having((e) => e.token, 'token', 'env:MISSING')),
      );
    });

    test('TWEC-RES-11: ~ and {home} both expand to home', () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {},
        homeDir: '/Users/test',
      );
      expect(resolver.resolve('~/x'), '/Users/test/x');
      expect(resolver.resolve('{home}/x'), '/Users/test/x');
    });

    test('TWEC-RES-12: {date} and {time} use the injected clock', () {
      final resolver = PlaceholderResolver(
        websiteScope: {},
        defaults: {},
        homeDir: '/home/test',
        clock: () => DateTime(2026, 6, 7, 9, 5, 3),
      );
      expect(resolver.resolve('{date}'), '2026-06-07');
      expect(resolver.resolve('{time}'), '09:05:03');
    });
  });

  group('PlaceholderResolver.forWebsite', () {
    test('TWEC-RES-13: builds scope from a loaded website + defaults', () {
      final result = loadWebsiteEditorConfig('''
version: 1
defaults:
  placeholders:
    repos: "/code"
websites:
  - id: site
    paths:
      websiteRoot: "{repos}/ef/website"
      builtDir: "{websiteRoot}/build"
    preview:
      devUrl: "http://localhost:{port}"
    cwd: "{websiteRoot}"
    commands:
      build: "jaspr build"
''');
      expect(result.isValid, isTrue, reason: result.issues.toString());
      final resolver = PlaceholderResolver.forWebsite(
        result.config!,
        result.config!.websites.first,
        builtins: {'port': '8080'},
        homeDir: '/home/test',
      );
      expect(resolver.resolve('{cwd}'), '/code/ef/website');
      expect(resolver.resolve('{builtDir}'), '/code/ef/website/build');
      expect(resolver.resolve('{devUrl}'), 'http://localhost:8080');
    });
  });
}

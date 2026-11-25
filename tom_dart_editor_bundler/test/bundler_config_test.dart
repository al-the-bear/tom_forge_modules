import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';
import 'package:test/test.dart';

/// The §6.1 example config, as it would appear in a consuming app's
/// buildkit.yaml under the `dart-editor-bundler` key.
const _validBuildkit = '''
dart-editor-bundler:
  out-dir: assets/summaries
  generated-helper: lib/generated/summary_scopes.g.dart
  sdk-summary: sdk_summary.sum
  bundles:
    - name: dart-plain
      sdk-only: true
      implicit-imports: [dart:async, dart:collection, dart:math]
    - name: d4rt-flutter
      packages:
        - ../../d4rt/tom_d4rt_flutter
      implicit-imports: [package:flutter/material.dart]
      allowed-package-prefixes: [package:flutter/, package:vector_math/]
      include-all-package-completions: true
    - name: d4rt-document
      packages:
        - ../../ai_build/tom_specs_model
      implicit-imports: [package:tom_specs_model/tom_specs_model.dart]
''';

void main() {
  group('BundlerConfig.fromYaml — valid multi-bundle config', () {
    late BundlerConfig config;

    setUp(() => config = BundlerConfig.fromYaml(_validBuildkit));

    test('reads top-level paths', () {
      expect(config.outDir, 'assets/summaries');
      expect(config.generatedHelper, 'lib/generated/summary_scopes.g.dart');
      expect(config.sdkSummary, 'sdk_summary.sum');
    });

    test('reads all three bundles in order', () {
      expect(config.bundles.map((b) => b.name), [
        'dart-plain',
        'd4rt-flutter',
        'd4rt-document',
      ]);
    });

    test('parses the sdk-only bundle', () {
      final plain = config.bundleByName('dart-plain')!;
      expect(plain.sdkOnly, isTrue);
      expect(plain.packages, isEmpty);
      expect(plain.implicitImports, [
        'dart:async',
        'dart:collection',
        'dart:math',
      ]);
    });

    test('parses a package-backed bundle with all optional fields', () {
      final flutter = config.bundleByName('d4rt-flutter')!;
      expect(flutter.sdkOnly, isFalse);
      expect(flutter.packages, ['../../d4rt/tom_d4rt_flutter']);
      expect(flutter.implicitImports, ['package:flutter/material.dart']);
      expect(flutter.allowedPackagePrefixes, [
        'package:flutter/',
        'package:vector_math/',
      ]);
      expect(flutter.includeAllPackageCompletions, isTrue);
    });
  });

  group('BundlerConfig — defaults', () {
    test('top-level paths default when omitted', () {
      final config = BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - name: only
      sdk-only: true
''');
      expect(config.outDir, BundlerConfig.defaultOutDir);
      expect(config.generatedHelper, BundlerConfig.defaultGeneratedHelper);
      expect(config.sdkSummary, BundlerConfig.defaultSdkSummary);
    });

    test('optional bundle fields default', () {
      final config = BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - name: only
      sdk-only: true
''');
      final only = config.bundles.single;
      expect(only.packages, isEmpty);
      expect(only.implicitImports, isEmpty);
      expect(only.allowedPackagePrefixes, isEmpty);
      expect(only.includeAllPackageCompletions, isFalse);
    });
  });

  group('BundlerConfig — validation', () {
    test('duplicate bundle name is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - name: dup
      sdk-only: true
    - name: dup
      packages: [pkg_a]
'''),
        throwsA(
          isA<BundlerConfigException>().having(
            (e) => e.message,
            'message',
            contains('dup'),
          ),
        ),
      );
    });

    test('empty packages without sdk-only is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - name: broken
'''),
        throwsA(
          isA<BundlerConfigException>().having(
            (e) => e.message,
            'message',
            contains('broken'),
          ),
        ),
      );
    });

    test('sdk-only combined with packages is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - name: contradictory
      sdk-only: true
      packages: [pkg_a]
'''),
        throwsA(isA<BundlerConfigException>()),
      );
    });

    test('missing/empty bundle name is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - sdk-only: true
'''),
        throwsA(isA<BundlerConfigException>()),
      );
    });

    test('empty bundles list is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles: []
'''),
        throwsA(isA<BundlerConfigException>()),
      );
    });

    test('missing dart-editor-bundler block is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('versioner:\n  variable-prefix: x\n'),
        throwsA(isA<BundlerConfigException>()),
      );
    });

    test('unknown top-level key is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  out_dir: typo
  bundles:
    - name: only
      sdk-only: true
'''),
        throwsA(isA<BundlerConfigException>()),
      );
    });

    test('the section\'s defines are not the bundler\'s keys '
        '[2026-11-16]', () {
      final config = BundlerConfig.fromYaml('''
dart-editor-bundler:
  defines:
    scope: only
  DEV-defines:
    scope: dev
  bundles:
    - name: only
      sdk-only: true
''');
      expect(config.bundles.single.name, 'only');
    });

    test('unknown per-bundle key is rejected', () {
      expect(
        () => BundlerConfig.fromYaml('''
dart-editor-bundler:
  bundles:
    - name: only
      sdk_only: true
'''),
        throwsA(isA<BundlerConfigException>()),
      );
    });
  });

  group('BundlerConfig.fromMap', () {
    test('parses a pre-extracted block map', () {
      final config = BundlerConfig.fromMap({
        'bundles': [
          {'name': 'a', 'sdk-only': true},
        ],
      });
      expect(config.bundles.single.name, 'a');
    });
  });
}

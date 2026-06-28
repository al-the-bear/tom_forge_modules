@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';
import 'package:test/test.dart';

/// Builds a self-contained fixture under the project's `ztmp/` (never `/tmp`):
///
///   `<root>/buildkit.yaml`           — a 2-scope dart-editor-bundler config
///   `<root>/pkgs/foo/lib/foo.dart`   — a synthetic package "foo"
///   `<root>/pkgs/foo/.dart_tool/package_config.json`
///
/// The `with-foo` scope folds `pkgs/foo` into its grouped bundle; the `plain`
/// scope is sdk-only.
Directory _writeFixture() {
  final base = Directory(p.join(
    Directory.current.path,
    'ztmp',
    'bundle_generator_test',
    DateTime.now().microsecondsSinceEpoch.toString(),
  ))
    ..createSync(recursive: true);

  final fooDir = Directory(p.join(base.path, 'pkgs', 'foo'))
    ..createSync(recursive: true);
  Directory(p.join(fooDir.path, 'lib')).createSync(recursive: true);
  File(p.join(fooDir.path, 'lib', 'foo.dart')).writeAsStringSync('''
/// Synthetic fixture library.
class Foo {
  int answer() => 42;
}
''');
  final fooDartTool = Directory(p.join(fooDir.path, '.dart_tool'))
    ..createSync(recursive: true);
  File(p.join(fooDartTool.path, 'package_config.json')).writeAsStringSync(
    jsonEncode({
      'configVersion': 2,
      'packages': [
        {
          'name': 'foo',
          'rootUri': '../',
          'packageUri': 'lib/',
          'languageVersion': '3.0',
        },
      ],
    }),
  );

  File(p.join(base.path, 'buildkit.yaml')).writeAsStringSync('''
dart-editor-bundler:
  out-dir: out
  bundles:
    - name: plain
      sdk-only: true
    - name: with-foo
      packages:
        - pkgs/foo
''');

  return base;
}

void main() {
  group('loadBundlerConfig', () {
    test('reads buildkit.yaml from the project dir and resolves baseDir', () {
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));

      final loaded = loadBundlerConfig(projectDir: base.path);
      expect(loaded.config.outDir, 'out');
      expect(loaded.config.bundles.map((b) => b.name), ['plain', 'with-foo']);
      expect(loaded.baseDir, p.normalize(base.absolute.path));
    });

    test('honors an explicit --config path', () {
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));

      final loaded = loadBundlerConfig(
        projectDir: Directory.current.path,
        configPath: p.join(base.path, 'buildkit.yaml'),
      );
      expect(loaded.baseDir, p.normalize(base.absolute.path));
    });

    test('throws a descriptive error when the config is missing', () {
      final missing = Directory(p.join(
        Directory.current.path,
        'ztmp',
        'bundle_generator_test',
        'absent-${DateTime.now().microsecondsSinceEpoch}',
      ));
      expect(
        () => loadBundlerConfig(projectDir: missing.path),
        throwsA(isA<BundlerConfigException>()),
      );
    });
  });

  group('BundleGenerator.generate — fixture asset tree', () {
    test('writes the expected tree and is idempotent', () async {
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));

      final loaded = loadBundlerConfig(projectDir: base.path);
      final gen = BundleGenerator();

      // First run.
      final first =
          await gen.generate(config: loaded.config, baseDir: loaded.baseDir);

      final outDir = p.join(base.path, 'out');
      final sdkSum = File(p.join(outDir, 'sdk_summary.sum'));
      final fooSum = File(p.join(outDir, 'with-foo', 'packages.sum'));
      final plainSum = File(p.join(outDir, 'plain', 'packages.sum'));

      expect(sdkSum.existsSync(), isTrue, reason: 'SDK summary written');
      expect(sdkSum.lengthSync(), greaterThan(0));
      expect(fooSum.existsSync(), isTrue, reason: 'package bundle written');
      expect(fooSum.lengthSync(), greaterThan(0));
      expect(plainSum.existsSync(), isFalse,
          reason: 'sdk-only scope gets no packages.sum');

      expect(first.sdkSummaryBuilt, isTrue);
      final fooResult = first.bundles.firstWhere((b) => b.name == 'with-foo');
      expect(fooResult.sdkOnly, isFalse);
      expect(fooResult.packageCount, greaterThanOrEqualTo(1));
      expect(fooResult.libraryCount, greaterThanOrEqualTo(1));
      final plainResult = first.bundles.firstWhere((b) => b.name == 'plain');
      expect(plainResult.sdkOnly, isTrue);
      expect(plainResult.packagesSumPath, isNull);

      // Second run: same tree, SDK summary reused (idempotent skip).
      final before = sdkSum.lastModifiedSync();
      final second =
          await gen.generate(config: loaded.config, baseDir: loaded.baseDir);

      expect(second.sdkSummaryBuilt, isFalse,
          reason: 'existing SDK summary is reused');
      expect(sdkSum.lastModifiedSync(), before,
          reason: 'SDK summary not rewritten');
      expect(sdkSum.existsSync(), isTrue);
      expect(fooSum.existsSync(), isTrue);
      expect(plainSum.existsSync(), isFalse);
    });

    test('--bundle filter builds only the named scope (plus shared SDK)',
        () async {
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));

      final loaded = loadBundlerConfig(projectDir: base.path);
      final result = await BundleGenerator().generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
        bundleFilter: 'with-foo',
      );

      expect(result.bundles.map((b) => b.name), ['with-foo']);
      expect(File(p.join(base.path, 'out', 'sdk_summary.sum')).existsSync(),
          isTrue);
      expect(
          File(p.join(base.path, 'out', 'with-foo', 'packages.sum'))
              .existsSync(),
          isTrue);
    });

    test('--bundle filter rejects an unknown scope name', () async {
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));

      final loaded = loadBundlerConfig(projectDir: base.path);
      expect(
        () => BundleGenerator().generate(
          config: loaded.config,
          baseDir: loaded.baseDir,
          bundleFilter: 'nope',
        ),
        throwsA(isA<BundlerConfigException>()),
      );
    });
  });
}

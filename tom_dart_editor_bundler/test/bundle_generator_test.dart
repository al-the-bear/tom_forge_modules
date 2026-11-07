@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_analyzer_shared/tom_analyzer_shared.dart'
    show summaryLibraryUris;
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
  final base = Directory(
    p.join(
      Directory.current.path,
      'ztmp',
      'bundle_generator_test',
      DateTime.now().microsecondsSinceEpoch.toString(),
    ),
  )..createSync(recursive: true);

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

/// Adds a miniature Flutter to the fixture at [base] — a `sky_engine` whose
/// `_embedder.yaml` adds a `dart:ui`, and a `flutter` whose `painting.dart`
/// re-exports from it — and a `flutter-ui` scope over a package resolved
/// against them.
void _addFlutterScope(Directory base) {
  void write(String path, String text) => (File(
    p.join(base.path, path),
  )..createSync(recursive: true)).writeAsStringSync(text);
  write('pkgs/sky_engine/lib/_embedder.yaml', '''
embedded_libs:
  "dart:ui": "ui/ui.dart"
''');
  write(
    'pkgs/sky_engine/lib/ui/ui.dart',
    'library dart.ui;\n\nenum TextDirection { rtl, ltr }\n',
  );
  write(
    'pkgs/flutter/lib/painting.dart',
    "export 'dart:ui' show TextDirection;\n",
  );
  write(
    'pkgs/app/lib/app.dart',
    "import 'package:flutter/painting.dart';\n"
        'const direction = TextDirection.ltr;\n',
  );
  write(
    'pkgs/app/.dart_tool/package_config.json',
    jsonEncode({
      'configVersion': 2,
      'packages': [
        for (final name in ['sky_engine', 'flutter'])
          {'name': name, 'rootUri': '../../$name', 'packageUri': 'lib/'},
        {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
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
    - name: flutter-ui
      packages:
        - pkgs/app
''');
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
      final missing = Directory(
        p.join(
          Directory.current.path,
          'ztmp',
          'bundle_generator_test',
          'absent-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
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
      final first = await gen.generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
      );

      final outDir = p.join(base.path, 'out');
      final sdkSum = File(p.join(outDir, 'sdk_summary.sum'));
      final fooSum = File(p.join(outDir, 'with-foo', 'packages.sum'));
      final plainSum = File(p.join(outDir, 'plain', 'packages.sum'));

      expect(sdkSum.existsSync(), isTrue, reason: 'SDK summary written');
      expect(sdkSum.lengthSync(), greaterThan(0));
      expect(fooSum.existsSync(), isTrue, reason: 'package bundle written');
      expect(fooSum.lengthSync(), greaterThan(0));
      expect(
        plainSum.existsSync(),
        isFalse,
        reason: 'sdk-only scope gets no packages.sum',
      );

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
      final second = await gen.generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
      );

      expect(
        second.sdkSummaryBuilt,
        isFalse,
        reason: 'existing SDK summary is reused',
      );
      expect(
        sdkSum.lastModifiedSync(),
        before,
        reason: 'SDK summary not rewritten',
      );
      expect(sdkSum.existsSync(), isTrue);
      expect(fooSum.existsSync(), isTrue);
      expect(plainSum.existsSync(), isFalse);
    });

    test(
      '--bundle filter builds only the named scope (plus shared SDK)',
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
        expect(
          File(p.join(base.path, 'out', 'sdk_summary.sum')).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(base.path, 'out', 'with-foo', 'packages.sum'),
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('the generated helper declares exactly the assets the run wrote', () async {
      // The claim this pins is the one that used to be made twice and checked
      // never: the asset keys `summary_scopes.g.dart` names are the paths the
      // generator writes. It is checkable at zero cost because the helper is a
      // *generated* file — it states the paths in plain text — so the round-trip
      // is both directions of one set comparison. A layout change made on only
      // one side of SummaryAssetLayout fails here rather than silently leaving
      // every code field on its plain-text fallback.
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));

      final loaded = loadBundlerConfig(projectDir: base.path);
      final result = await BundleGenerator().generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
      );
      final helper = generateScopeInitHelper(loaded.config);

      final declared = RegExp(
        r"(?:sdk|package)SummaryAsset: '([^']+)'",
      ).allMatches(helper).map((m) => m.group(1)!).toSet();
      expect(declared, isNotEmpty, reason: 'helper declares asset keys at all');

      // Forward: nothing the app asks for is missing from disk.
      for (final key in declared) {
        expect(
          File(p.join(loaded.baseDir, key)).existsSync(),
          isTrue,
          reason: 'declared asset "$key" was not written by the generator',
        );
      }

      // Backward: nothing the generator writes goes unasked-for. A bundle
      // written to a path no scope names is dead weight in the app bundle and
      // means a scope is silently unbacked.
      String assetKeyOf(String absolute) =>
          p.url.joinAll(p.split(p.relative(absolute, from: loaded.baseDir)));
      final written = <String>{
        assetKeyOf(result.sdkSummaryPath),
        for (final b in result.bundles)
          if (b.packagesSumPath != null) assetKeyOf(b.packagesSumPath!),
      };
      expect(written, declared);
    });

    test('a Flutter scope: the shared SDK summary holds dart:ui and the '
        'bundles link against the same embedder; a summary built without it '
        'is rebuilt, and a run without Flutter keeps the plain SDK', () async {
      final base = _writeFixture();
      addTearDown(() => base.deleteSync(recursive: true));
      final sdkSum = File(p.join(base.path, 'out', 'sdk_summary.sum'));

      // Without a Flutter scope: the plain SDK.
      var loaded = loadBundlerConfig(projectDir: base.path);
      var result = await BundleGenerator().generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
      );
      expect(result.embedderYamlPath, isNull);
      expect(
        summaryLibraryUris(sdkSum.readAsBytesSync()),
        isNot(contains('dart:ui')),
      );

      // A Flutter scope added: the summary without dart:ui is stale. A run
      // filtered to another scope still builds the shared summary with it.
      _addFlutterScope(base);
      loaded = loadBundlerConfig(projectDir: base.path);
      result = await BundleGenerator().generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
        bundleFilter: 'with-foo',
      );
      final embedder = p.normalize(
        p.join(base.path, 'pkgs', 'sky_engine', 'lib', '_embedder.yaml'),
      );
      expect(result.embedderYamlPath, embedder);
      expect(result.sdkSummaryBuilt, isTrue);
      expect(summaryLibraryUris(sdkSum.readAsBytesSync()), contains('dart:ui'));

      result = await BundleGenerator().generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
        bundleFilter: 'flutter-ui',
      );
      expect(result.sdkSummaryBuilt, isFalse, reason: 'now up to date');
      final flutterSum = File(
        p.join(base.path, 'out', 'flutter-ui', 'packages.sum'),
      );
      expect(
        summaryLibraryUris(flutterSum.readAsBytesSync()),
        containsAll(['package:flutter/painting.dart', 'package:app/app.dart']),
      );
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

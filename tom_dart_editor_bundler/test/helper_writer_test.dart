@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';
import 'package:test/test.dart';

/// The two fully-specified scopes from spec §6.3 (an sdk-only scope and a
/// package scope with implicit imports + allowed prefixes). Pinning these two
/// reproduces the worked example in the spec verbatim.
BundlerConfig _goldenConfig() => const BundlerConfig(
      outDir: 'assets/summaries',
      generatedHelper: 'lib/generated/summary_scopes.g.dart',
      sdkSummary: 'sdk_summary.sum',
      bundles: [
        SummaryBundleSpec(
          name: 'dart-plain',
          sdkOnly: true,
          implicitImports: ['dart:async', 'dart:collection', 'dart:math'],
        ),
        SummaryBundleSpec(
          name: 'd4rt-flutter',
          packages: ['pkgs/d4rt_flutter'],
          implicitImports: ['package:flutter/material.dart'],
          allowedPackagePrefixes: ['package:flutter/', 'package:vector_math/'],
        ),
      ],
    );

/// The exact source the golden config must produce — mirrors spec §6.3.
const String _goldenSource = '''
// GENERATED — do not edit. Produced by tom_dart_editor_bundler.
import 'package:tom_dart_editor/tom_dart_editor.dart';

abstract final class SummaryScopes {
  static const dartPlain = 'dart-plain';
  static const d4rtFlutter = 'd4rt-flutter';

  /// Loads + parses every bundle once and registers it by name. Idempotent.
  static Future<void> initialize() async {
    await SummaryScopeRegistry.instance.register(
      const SummaryScopeAsset(
        name: dartPlain,
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: null,
        implicitImports: ['dart:async', 'dart:collection', 'dart:math'],
      ),
    );
    await SummaryScopeRegistry.instance.register(
      const SummaryScopeAsset(
        name: d4rtFlutter,
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/d4rt-flutter/packages.sum',
        implicitImports: ['package:flutter/material.dart'],
        allowedPackagePrefixes: ['package:flutter/', 'package:vector_math/'],
      ),
    );
  }
}
''';

/// Minimal stub of the `tom_dart_editor` API surface the generated helper
/// targets (`SummaryScopeAsset` + `SummaryScopeRegistry`). The real types land
/// in `tom_dart_editor` in a later plan item; this fixture lets us prove the
/// generated source *analyzes clean against the documented contract* now.
const String _tomDartEditorStub = '''
/// Test stub mirroring the spec §6.4 descriptor + registry surface.
class SummaryScopeAsset {
  final String name;
  final String sdkSummaryAsset;
  final String? packageSummaryAsset;
  final List<String> implicitImports;
  final List<String> allowedPackagePrefixes;
  const SummaryScopeAsset({
    required this.name,
    required this.sdkSummaryAsset,
    this.packageSummaryAsset,
    this.implicitImports = const [],
    this.allowedPackagePrefixes = const [],
  });
}

class SummaryScopeRegistry {
  static final SummaryScopeRegistry instance = SummaryScopeRegistry._();
  SummaryScopeRegistry._();
  Future<void> register(SummaryScopeAsset asset) async {}
}
''';

void main() {
  group('generateScopeInitHelper', () {
    test('matches the spec §6.3 golden source exactly', () {
      expect(generateScopeInitHelper(_goldenConfig()), _goldenSource);
    });

    test('camelCases names and omits empty allowed-prefixes', () {
      const config = BundlerConfig(
        outDir: 'assets/summaries',
        generatedHelper: 'lib/generated/summary_scopes.g.dart',
        sdkSummary: 'sdk_summary.sum',
        bundles: [
          SummaryBundleSpec(name: 'dart-plain', sdkOnly: true),
        ],
      );
      final src = generateScopeInitHelper(config);
      expect(src, contains("static const dartPlain = 'dart-plain';"));
      // sdk-only → null package asset, empty implicit imports.
      expect(src, contains('packageSummaryAsset: null,'));
      expect(src, contains('implicitImports: [],'));
      // No allowed-prefixes line when the list is empty.
      expect(src, isNot(contains('allowedPackagePrefixes:')));
    });
  });

  group('writeScopeInitHelper', () {
    test('writes the file at generatedHelper relative to baseDir', () {
      final base = Directory(p.join(
        Directory.current.path,
        'ztmp',
        'helper_writer_test',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ))
        ..createSync(recursive: true);
      addTearDown(() => base.deleteSync(recursive: true));

      final result = writeScopeInitHelper(
        config: _goldenConfig(),
        baseDir: base.path,
      );

      final expected =
          p.normalize(p.join(base.path, 'lib/generated/summary_scopes.g.dart'));
      expect(result.path, expected);
      expect(result.scopeCount, 2);
      expect(File(expected).readAsStringSync(), _goldenSource);
    });
  });

  group('generated helper analyzes clean against the documented API', () {
    test('dart analyze reports no issues for the emitted source', () async {
      final pkg = Directory(p.join(
        Directory.current.path,
        'ztmp',
        'helper_writer_test',
        'consumer-${DateTime.now().microsecondsSinceEpoch}',
      ))
        ..createSync(recursive: true);
      addTearDown(() => pkg.deleteSync(recursive: true));

      // A self-contained package literally named `tom_dart_editor` so the
      // generated `import 'package:tom_dart_editor/...'` resolves to the stub.
      File(p.join(pkg.path, 'pubspec.yaml')).writeAsStringSync('''
name: tom_dart_editor
environment:
  sdk: ^3.0.0
''');
      final libDir = Directory(p.join(pkg.path, 'lib'))
        ..createSync(recursive: true);
      File(p.join(libDir.path, 'tom_dart_editor.dart'))
          .writeAsStringSync(_tomDartEditorStub);

      // Emit the helper into the stub package at its configured location.
      writeScopeInitHelper(config: _goldenConfig(), baseDir: pkg.path);

      final pubGet = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: pkg.path,
      );
      expect(pubGet.exitCode, 0,
          reason: 'pub get failed: ${pubGet.stderr}\n${pubGet.stdout}');

      final analyze = await Process.run(
        'dart',
        ['analyze', '--fatal-infos', '--fatal-warnings'],
        workingDirectory: pkg.path,
      );
      expect(analyze.exitCode, 0,
          reason: 'analyze reported issues:\n${analyze.stdout}\n${analyze.stderr}');
    });
  });
}

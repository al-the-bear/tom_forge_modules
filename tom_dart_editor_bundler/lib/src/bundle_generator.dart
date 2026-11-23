/// tom_dart_editor_bundler — config → `.sum` asset set generator (plan item 5).
///
/// Turns a parsed [BundlerConfig] into the on-disk asset tree the
/// `tom_dart_analysis` runtime loads. Where each file goes is [SummaryAssetLayout]'s
/// to say — the same declaration the generated scope-init helper derives its
/// asset keys from, so the tree written here is the tree the app asks for.
///
/// The grouped `packages.sum` build is delegated to `tom_analyzer_shared`'s
/// [GroupedPackageBundleBuilder] (base-first owner of the load-bearing
/// package-resolver order). The one-shot SDK summary is produced here via the
/// analyzer's *public* `buildSdkSummary` API — the same generator-layer split
/// `tom_specs_clitool/bin/summaries.dart` uses.
///
/// A scope of Flutter packages needs Flutter's embedder libraries (`dart:ui`
/// …) on both sides: the shared SDK summary is built with the embedder of the
/// declared scopes' `sky_engine`, and each grouped bundle is linked against
/// the same one, so the `dart:ui` types Flutter re-exports resolve.
///
/// Every summary written gets a [SummaryStamp] beside it (`<file>.stamp`):
/// the Dart SDK, the analyzer data version (the exact key of the summary
/// format) and the Flutter embedder. The run is idempotent/re-runnable: the
/// SDK summary is kept while its stamp is the one this run would write, and
/// each `packages.sum` is rebuilt and overwritten deterministically from the
/// same inputs, so a second run yields the same asset tree. A run whose
/// analyzer differs from the one the consuming app resolves is refused: the
/// app could not read what it writes.
library;

import 'dart:io';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:tom_analyzer_shared/tom_analyzer_shared.dart'
    show
        GroupedPackageBundleBuilder,
        SummaryStamp,
        analyzerDataVersion,
        analyzerDataVersionInPackageRoots,
        flutterEmbedderYamlInPackageRoots,
        readPackageRoots,
        resolveDartSdkPath;

import 'asset_layout.dart';
import 'bundler_config.dart';

/// One scope's generation outcome.
class GeneratedBundle {
  /// The scope (bundle) name.
  final String name;

  /// Whether the scope is SDK-only (no `packages.sum` produced).
  final bool sdkOnly;

  /// Absolute path of the written `packages.sum`, or null for SDK-only scopes.
  final String? packagesSumPath;

  /// Number of packages folded into the grouped bundle (0 for SDK-only).
  final int packageCount;

  /// Number of libraries summarized (0 for SDK-only).
  final int libraryCount;

  const GeneratedBundle({
    required this.name,
    required this.sdkOnly,
    required this.packagesSumPath,
    required this.packageCount,
    required this.libraryCount,
  });
}

/// Result of a [BundleGenerator.generate] run.
class BundleGenerationResult {
  /// Absolute path of the shared SDK summary asset.
  final String sdkSummaryPath;

  /// True when the SDK summary was (re)built this run; false when an existing
  /// summary was reused (idempotent skip).
  final bool sdkSummaryBuilt;

  /// Per-scope outcomes, in declaration order (filtered when `--bundle` is set).
  final List<GeneratedBundle> bundles;

  /// The Flutter embedder the SDK summary and the bundles were built with,
  /// or null when no scope holds Flutter packages.
  final String? embedderYamlPath;

  const BundleGenerationResult({
    required this.sdkSummaryPath,
    required this.sdkSummaryBuilt,
    required this.bundles,
    this.embedderYamlPath,
  });
}

/// Loads and parses the `dart-editor-bundler` config and resolves the base
/// directory that `out-dir` / `packages` paths are interpreted against.
///
/// When [configPath] is given it is used verbatim (relative to the current
/// working directory) and the base directory is the file's parent. Otherwise the
/// project's `buildkit.yaml` ([projectDir]/buildkit.yaml) is read and the base
/// directory is [projectDir].
///
/// Throws [BundlerConfigException] if the file is absent or malformed.
({BundlerConfig config, String baseDir}) loadBundlerConfig({
  required String projectDir,
  String? configPath,
}) {
  final file = configPath != null
      ? File(configPath)
      : File(p.join(projectDir, TomBundlerFiles.buildkit));
  if (!file.existsSync()) {
    throw BundlerConfigException(
      'config file not found: ${file.path}',
      source: file.path,
    );
  }
  final config =
      BundlerConfig.fromYaml(file.readAsStringSync(), source: file.path);
  return (config: config, baseDir: p.dirname(file.absolute.path));
}

/// Well-known filenames the bundler reads.
abstract final class TomBundlerFiles {
  /// The project-level build configuration the bundler reads by default.
  static const String buildkit = 'buildkit.yaml';
}

/// Generates the summary `.sum` asset tree from a [BundlerConfig].
class BundleGenerator {
  /// Resource provider used for analyzer summary building (defaults to the
  /// physical file system).
  final PhysicalResourceProvider resourceProvider;

  BundleGenerator({PhysicalResourceProvider? resourceProvider})
      : resourceProvider =
            resourceProvider ?? PhysicalResourceProvider.INSTANCE;

  /// Build the asset tree described by [config], resolving relative `out-dir`
  /// and `packages` paths against [baseDir].
  ///
  /// [bundleFilter] restricts the run to a single named scope (the `--bundle`
  /// option); the shared SDK summary is still emitted because every scope
  /// depends on it. [sdkPath] overrides SDK discovery; [log] receives progress
  /// lines.
  ///
  /// Throws [BundlerConfigException] when [bundleFilter] names no declared scope
  /// or when the SDK cannot be located.
  Future<BundleGenerationResult> generate({
    required BundlerConfig config,
    required String baseDir,
    String? bundleFilter,
    String? sdkPath,
    void Function(String)? log,
  }) async {
    final logLine = log ?? (_) {};

    final selected = _selectBundles(config, bundleFilter);

    final resolvedSdkPath = sdkPath ?? resolveDartSdkPath();
    if (resolvedSdkPath == null) {
      throw BundlerConfigException(
        'could not locate the Dart SDK (set sdkPath or ensure the SDK is on '
        'PATH)',
      );
    }

    _checkAnalyzerOfApp(baseDir, logLine);

    Directory(_resolve(baseDir, config.outDir)).createSync(recursive: true);

    // The Flutter embedder of every declared scope (not only the selected
    // ones), so a filtered run writes the same shared SDK summary.
    final embedder = _flutterEmbedderOf(config, baseDir);
    if (embedder != null) logLine('Flutter embedder: $embedder');

    // ── shared SDK summary (idempotent: kept while the stamp beside it is
    // the one this run would write — the same analyzer data version, Dart
    // SDK and Flutter embedder) ─────────────────────────────────────────────
    final sdkSummaryPath = SummaryAssetLayout.filePath(
        baseDir, SummaryAssetLayout.sdkSummarySegments(config));
    final sdkFile = File(sdkSummaryPath);
    final stamp = SummaryStamp.current(embedderYamlPath: embedder);
    bool sdkBuilt = false;
    if (stamp.isCurrentFor(sdkSummaryPath)) {
      logLine('SDK summary up to date: $sdkSummaryPath');
    } else {
      logLine('Building SDK summary...');
      final bytes = await buildSdkSummary(
        resourceProvider: resourceProvider,
        sdkPath: resolvedSdkPath,
        embedderYamlPath: embedder,
      );
      sdkFile.writeAsBytesSync(bytes);
      stamp.writeFor(sdkSummaryPath);
      sdkBuilt = true;
      logLine('  → $sdkSummaryPath (${bytes.length} bytes)');
    }

    // ── per-scope grouped package bundles ──────────────────────────────────
    final results = <GeneratedBundle>[];
    for (final bundle in selected) {
      if (bundle.sdkOnly) {
        logLine('Scope "${bundle.name}": sdk-only (no packages.sum)');
        results.add(GeneratedBundle(
          name: bundle.name,
          sdkOnly: true,
          packagesSumPath: null,
          packageCount: 0,
          libraryCount: 0,
        ));
        continue;
      }

      logLine('Scope "${bundle.name}": building packages.sum...');
      final dirs =
          bundle.packages.map((pkg) => _resolve(baseDir, pkg)).toList();
      final grouped = await GroupedPackageBundleBuilder(
        resourceProvider: resourceProvider,
      ).buildFromDirs(
        dirs,
        sdkPath: resolvedSdkPath,
        embedderYamlPath: embedder,
        onLog: logLine,
      );

      final packagesSumPath = SummaryAssetLayout.filePath(
          baseDir, SummaryAssetLayout.packagesSegments(config, bundle)!);
      final file = File(packagesSumPath);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(grouped.bytes);
      stamp.writeFor(packagesSumPath);
      logLine('  → $packagesSumPath (${grouped.bytes.length} bytes, '
          '${grouped.packageCount} packages, ${grouped.libraryCount} libraries)');

      results.add(GeneratedBundle(
        name: bundle.name,
        sdkOnly: false,
        packagesSumPath: packagesSumPath,
        packageCount: grouped.packageCount,
        libraryCount: grouped.libraryCount,
      ));
    }

    return BundleGenerationResult(
      sdkSummaryPath: sdkSummaryPath,
      sdkSummaryBuilt: sdkBuilt,
      bundles: results,
      embedderYamlPath: embedder,
    );
  }

  /// Refuses to write summaries the app at [baseDir] could not read: the
  /// analyzer it resolves (its `.dart_tool/package_config.json`) must have
  /// this bundler's analyzer data version, the exact key of the summary
  /// format. An app with no resolved config or no analyzer is not checked.
  void _checkAnalyzerOfApp(String baseDir, void Function(String) log) {
    final config = File(p.join(baseDir, '.dart_tool', 'package_config.json'));
    if (!config.existsSync()) {
      log('No resolved package config in $baseDir: the app\'s analyzer is '
          'not checked');
      return;
    }
    final appVersion =
        analyzerDataVersionInPackageRoots(readPackageRoots(config));
    if (appVersion == null) {
      log('$baseDir resolves no analyzer: not checked');
      return;
    }
    if (appVersion != analyzerDataVersion) {
      throw BundlerConfigException(
        'the app at $baseDir resolves an analyzer with data version '
        '$appVersion, this bundler links data version $analyzerDataVersion: '
        'the summaries it writes would not be readable there. Resolve both '
        'with the same Dart SDK (`dart pub get` in the bundler and '
        '`flutter pub get` in the app, the same Flutter on PATH) and run '
        'again.',
      );
    }
  }

  /// The embedder of the first `sky_engine` among the packages of [config]'s
  /// scopes, or null when none holds Flutter. A package directory without a
  /// resolved config is passed over here; building its scope reports it.
  String? _flutterEmbedderOf(BundlerConfig config, String baseDir) {
    for (final bundle in config.bundles) {
      if (bundle.sdkOnly) continue;
      for (final package in bundle.packages) {
        final packageConfig = File(p.join(
          _resolve(baseDir, package),
          '.dart_tool',
          'package_config.json',
        ));
        if (!packageConfig.existsSync()) continue;
        final embedder =
            flutterEmbedderYamlInPackageRoots(readPackageRoots(packageConfig));
        if (embedder != null) return embedder;
      }
    }
    return null;
  }

  /// Resolve [pathOrDir] against [baseDir] when relative; normalize either way.
  String _resolve(String baseDir, String pathOrDir) => p.normalize(
        p.isAbsolute(pathOrDir) ? pathOrDir : p.join(baseDir, pathOrDir),
      );

  /// Select the scopes to build, honoring an optional single-bundle filter.
  List<SummaryBundleSpec> _selectBundles(
    BundlerConfig config,
    String? bundleFilter,
  ) {
    if (bundleFilter == null) return config.bundles;
    final match = config.bundleByName(bundleFilter);
    if (match == null) {
      throw BundlerConfigException(
        'no bundle named "$bundleFilter" (declared: '
        '${config.bundles.map((b) => b.name).join(', ')})',
      );
    }
    return [match];
  }
}

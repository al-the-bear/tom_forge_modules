/// tom_dart_editor_bundler — configuration model + parser.
///
/// Typed representation of the `dart-editor-bundler` block (spec §6.1) that a
/// consuming Flutter app declares in its `buildkit.yaml`. The markdown spec is
/// the human-readable schema; this model is the parsed, validated source of
/// truth the bundler operates on.
library;

import 'package:tom_build_base/tom_build_base.dart' show withoutDefines;
import 'package:yaml/yaml.dart';

/// The top-level buildkit.yaml key under which the bundler config lives.
const String kBundlerConfigKey = 'dart-editor-bundler';

/// Thrown when the `dart-editor-bundler` configuration is missing, malformed,
/// or fails a schema invariant. The [message] identifies the offending field
/// or bundle so the failure is actionable from the CLI.
class BundlerConfigException implements Exception {
  /// Human-readable description of what is wrong with the configuration.
  final String message;

  /// Optional source identifier (e.g. a file path) for context.
  final String? source;

  BundlerConfigException(this.message, {this.source});

  @override
  String toString() {
    final where = source == null ? '' : ' ($source)';
    return 'BundlerConfigException$where: $message';
  }
}

/// One summary scope — a named analysis surface (spec §6.1, per-bundle fields).
class SummaryBundleSpec {
  /// Recognised per-bundle keys; anything else is treated as a typo.
  static const Set<String> knownKeys = {
    'name',
    'packages',
    'sdk-only',
    'implicit-imports',
    'allowed-package-prefixes',
    'include-all-package-completions',
  };

  /// Scope id — the asset sub-dir, the registry key, and the generated constant
  /// name. Must be unique across the config.
  final String name;

  /// Package dirs whose resolved closures (union) form `packages.sum`. Empty
  /// only when [sdkOnly] is true.
  final List<String> packages;

  /// When true, no `packages.sum` is built; the scope resolves SDK types only.
  final bool sdkOnly;

  /// Imports auto-prepended to the analysed snippet (drives baseline
  /// completions).
  final List<String> implicitImports;

  /// Optional completion filter (the adapter's `allowedPackagePrefixes`).
  final List<String> allowedPackagePrefixes;

  /// Optional flag mapped to the adapter's `includeAllPackageCompletions`.
  final bool includeAllPackageCompletions;

  const SummaryBundleSpec({
    required this.name,
    this.packages = const [],
    this.sdkOnly = false,
    this.implicitImports = const [],
    this.allowedPackagePrefixes = const [],
    this.includeAllPackageCompletions = false,
  });

  /// Parse one bundle entry from its (Yaml or plain) map representation.
  factory SummaryBundleSpec.fromMap(Map<dynamic, dynamic> map, {String? source}) {
    _rejectUnknownKeys(map, knownKeys, 'bundle', source);

    final name = _readString(map, 'name', source: source);
    if (name == null || name.trim().isEmpty) {
      throw BundlerConfigException(
        'each bundle requires a non-empty "name"',
        source: source,
      );
    }

    final packages = _readStringList(map, 'packages', name, source: source);
    final sdkOnly = _readBool(map, 'sdk-only', name, source: source) ?? false;

    if (sdkOnly && packages.isNotEmpty) {
      throw BundlerConfigException(
        'bundle "$name" sets sdk-only: true but also lists packages; '
        'an sdk-only scope builds no packages.sum',
        source: source,
      );
    }
    if (!sdkOnly && packages.isEmpty) {
      throw BundlerConfigException(
        'bundle "$name" has no packages; set sdk-only: true for an '
        'SDK-only scope, or list at least one package',
        source: source,
      );
    }

    return SummaryBundleSpec(
      name: name,
      packages: packages,
      sdkOnly: sdkOnly,
      implicitImports:
          _readStringList(map, 'implicit-imports', name, source: source),
      allowedPackagePrefixes: _readStringList(
          map, 'allowed-package-prefixes', name,
          source: source),
      includeAllPackageCompletions:
          _readBool(map, 'include-all-package-completions', name, source: source) ??
              false,
    );
  }
}

/// Parsed `dart-editor-bundler` configuration (spec §6.1).
class BundlerConfig {
  /// Default output directory for generated `.sum` assets.
  static const String defaultOutDir = 'assets/summaries';

  /// Default path for the generated scope-init helper Dart file.
  static const String defaultGeneratedHelper =
      'lib/generated/summary_scopes.g.dart';

  /// Default filename for the shared SDK summary.
  static const String defaultSdkSummary = 'sdk_summary.sum';

  /// Recognised top-level keys; anything else is treated as a typo.
  static const Set<String> knownKeys = {
    'out-dir',
    'generated-helper',
    'sdk-summary',
    'bundles',
  };

  /// Where the generated `.sum` assets are written (under the app's assets/).
  final String outDir;

  /// Where the generated scope-init helper Dart file is written.
  final String generatedHelper;

  /// Filename of the shared SDK summary (generated once, referenced by all).
  final String sdkSummary;

  /// The declared summary scopes, in declaration order.
  final List<SummaryBundleSpec> bundles;

  const BundlerConfig({
    required this.outDir,
    required this.generatedHelper,
    required this.sdkSummary,
    required this.bundles,
  });

  /// Find a bundle by [name], or null if absent.
  SummaryBundleSpec? bundleByName(String name) {
    for (final b in bundles) {
      if (b.name == name) return b;
    }
    return null;
  }

  /// Parse a full buildkit-style YAML document and extract the
  /// `dart-editor-bundler` block.
  ///
  /// Throws [BundlerConfigException] if the document is not a YAML map or has no
  /// `dart-editor-bundler` block.
  factory BundlerConfig.fromYaml(String yamlSource, {String? source}) {
    final dynamic doc;
    try {
      doc = loadYaml(yamlSource);
    } on YamlException catch (e) {
      throw BundlerConfigException('invalid YAML: $e', source: source);
    }
    if (doc is! Map) {
      throw BundlerConfigException(
        'expected a YAML map at the document root',
        source: source,
      );
    }
    final block = doc[kBundlerConfigKey];
    if (block == null) {
      throw BundlerConfigException(
        'no "$kBundlerConfigKey" block found',
        source: source,
      );
    }
    if (block is! Map) {
      throw BundlerConfigException(
        '"$kBundlerConfigKey" must be a map',
        source: source,
      );
    }
    // The section's `defines:` / `<MODE>-defines:` are ToolRunner's, not
    // the bundler's keys.
    return BundlerConfig.fromMap(withoutDefines(block), source: source);
  }

  /// Parse a pre-extracted `dart-editor-bundler` block map.
  factory BundlerConfig.fromMap(Map<dynamic, dynamic> map, {String? source}) {
    _rejectUnknownKeys(map, knownKeys, kBundlerConfigKey, source);

    final rawBundles = map['bundles'];
    if (rawBundles == null) {
      throw BundlerConfigException(
        '"$kBundlerConfigKey" requires a non-empty "bundles" list',
        source: source,
      );
    }
    if (rawBundles is! List || rawBundles.isEmpty) {
      throw BundlerConfigException(
        '"bundles" must be a non-empty list',
        source: source,
      );
    }

    final bundles = <SummaryBundleSpec>[];
    final seen = <String>{};
    for (final entry in rawBundles) {
      if (entry is! Map) {
        throw BundlerConfigException(
          'each "bundles" entry must be a map',
          source: source,
        );
      }
      final bundle = SummaryBundleSpec.fromMap(entry, source: source);
      if (!seen.add(bundle.name)) {
        throw BundlerConfigException(
          'duplicate bundle name "${bundle.name}"',
          source: source,
        );
      }
      bundles.add(bundle);
    }

    return BundlerConfig(
      outDir: _readString(map, 'out-dir', source: source) ?? defaultOutDir,
      generatedHelper: _readString(map, 'generated-helper', source: source) ??
          defaultGeneratedHelper,
      sdkSummary:
          _readString(map, 'sdk-summary', source: source) ?? defaultSdkSummary,
      bundles: bundles,
    );
  }
}

// =============================================================================
// Shared parsing helpers
// =============================================================================

void _rejectUnknownKeys(
  Map<dynamic, dynamic> map,
  Set<String> known,
  String context,
  String? source,
) {
  for (final key in map.keys) {
    if (!known.contains(key)) {
      throw BundlerConfigException(
        'unknown $context key "$key" (expected one of: '
        '${known.join(', ')})',
        source: source,
      );
    }
  }
}

String? _readString(Map<dynamic, dynamic> map, String key, {String? source}) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw BundlerConfigException(
      '"$key" must be a string, got ${value.runtimeType}',
      source: source,
    );
  }
  return value;
}

bool? _readBool(
  Map<dynamic, dynamic> map,
  String key,
  String bundleName, {
  String? source,
}) {
  final value = map[key];
  if (value == null) return null;
  if (value is! bool) {
    throw BundlerConfigException(
      'bundle "$bundleName": "$key" must be a boolean, got ${value.runtimeType}',
      source: source,
    );
  }
  return value;
}

List<String> _readStringList(
  Map<dynamic, dynamic> map,
  String key,
  String bundleName, {
  String? source,
}) {
  final value = map[key];
  if (value == null) return const [];
  if (value is! List) {
    throw BundlerConfigException(
      'bundle "$bundleName": "$key" must be a list of strings, '
      'got ${value.runtimeType}',
      source: source,
    );
  }
  return value.map((e) {
    if (e is! String) {
      throw BundlerConfigException(
        'bundle "$bundleName": "$key" entries must be strings, '
        'got ${e.runtimeType}',
        source: source,
      );
    }
    return e;
  }).toList(growable: false);
}

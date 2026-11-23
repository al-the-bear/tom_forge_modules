/// tom_dart_editor_bundler — generated scope-init helper writer (spec §6.3).
///
/// Emits the `generated-helper` Dart file the consuming app imports and calls
/// once at startup: an `abstract final class SummaryScopes` exposing a `const`
/// name per bundle plus an idempotent `initialize()` that registers every
/// bundle with `tom_dart_analysis`'s `SummaryScopeRegistry` (the Dart editor's
/// analysis, a plugin of `tom_dart_editor`).
///
/// The generated source references `SummaryScopeAsset` / `SummaryScopeRegistry`
/// from `package:tom_dart_analysis/tom_dart_analysis.dart`. This module owns only the *text generation* and file write; it does
/// not depend on those types itself.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'asset_layout.dart';
import 'bundler_config.dart';

/// Result of writing the generated scope-init helper.
class HelperWriteResult {
  /// Absolute path of the written Dart file.
  final String path;

  /// Number of bundle scopes registered by the generated `initialize()`.
  final int scopeCount;

  const HelperWriteResult({required this.path, required this.scopeCount});
}

/// Renders the scope-init helper Dart source for [config] (spec §6.3).
///
/// Pure and deterministic — the same config always yields byte-identical
/// output, which is what the golden-file test pins. Asset keys are read off
/// [SummaryAssetLayout], the single declaration the bundle generator writes by,
/// so a declared key is always a file the generator produces.
String generateScopeInitHelper(BundlerConfig config) {
  final buf = StringBuffer();
  buf.writeln(
      '// GENERATED — do not edit. Produced by tom_dart_editor_bundler.');
  buf.writeln("import 'package:tom_dart_analysis/tom_dart_analysis.dart';");
  buf.writeln();
  buf.writeln('abstract final class SummaryScopes {');
  for (final bundle in config.bundles) {
    buf.writeln("  static const ${_camelCase(bundle.name)} = '${bundle.name}';");
  }
  buf.writeln();
  buf.writeln('  /// Loads + parses every bundle once and registers it by name. '
      'Idempotent.');
  buf.writeln('  static Future<void> initialize() async {');
  for (final bundle in config.bundles) {
    _writeRegistration(buf, config, bundle);
  }
  buf.writeln('  }');
  buf.writeln('}');
  return buf.toString();
}

/// Renders and writes the helper to `<baseDir>/<config.generatedHelper>`,
/// creating parent directories as needed.
HelperWriteResult writeScopeInitHelper({
  required BundlerConfig config,
  required String baseDir,
  void Function(String message)? log,
}) {
  final source = generateScopeInitHelper(config);
  final target = p.normalize(
    p.isAbsolute(config.generatedHelper)
        ? config.generatedHelper
        : p.join(baseDir, config.generatedHelper),
  );
  final file = File(target);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(source);
  log?.call('wrote scope-init helper: $target (${config.bundles.length} scope(s))');
  return HelperWriteResult(path: target, scopeCount: config.bundles.length);
}

void _writeRegistration(
  StringBuffer buf,
  BundlerConfig config,
  SummaryBundleSpec bundle,
) {
  // Asset keys come from SummaryAssetLayout, the same declaration the
  // BundleGenerator writes by — the helper cannot name a path the generator
  // does not produce.
  final sdkAsset = SummaryAssetLayout.assetKey(
      SummaryAssetLayout.sdkSummarySegments(config));
  final packagesSegments = SummaryAssetLayout.packagesSegments(config, bundle);
  final packageAsset = packagesSegments == null
      ? null
      : SummaryAssetLayout.assetKey(packagesSegments);

  buf.writeln('    await SummaryScopeRegistry.instance.register(');
  buf.writeln('      const SummaryScopeAsset(');
  buf.writeln('        name: ${_camelCase(bundle.name)},');
  buf.writeln("        sdkSummaryAsset: '$sdkAsset',");
  buf.writeln(packageAsset == null
      ? '        packageSummaryAsset: null,'
      : "        packageSummaryAsset: '$packageAsset',");
  buf.writeln('        implicitImports: ${_dartStringList(bundle.implicitImports)},');
  if (bundle.allowedPackagePrefixes.isNotEmpty) {
    buf.writeln('        allowedPackagePrefixes: '
        '${_dartStringList(bundle.allowedPackagePrefixes)},');
  }
  buf.writeln('      ),');
  buf.writeln('    );');
}

/// `dart-plain` → `dartPlain`, `d4rt-flutter` → `d4rtFlutter`. Splits on `-`
/// and `_`; lowercases the first segment, capitalizes the rest.
String _camelCase(String name) {
  final segments = name
      .split(RegExp(r'[-_]'))
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) return name;
  final head = segments.first.toLowerCase();
  final tail = segments.skip(1).map((s) {
    return s[0].toUpperCase() + s.substring(1);
  });
  return '$head${tail.join()}';
}

/// Renders a Dart list literal of single-quoted strings: `['a', 'b']`, `[]`.
String _dartStringList(List<String> values) {
  // Already inside a `const SummaryScopeAsset(...)` invocation, so the list
  // literal is implicitly const — no `const` prefix needed.
  if (values.isEmpty) return '[]';
  return '[${values.map((v) => "'$v'").join(', ')}]';
}

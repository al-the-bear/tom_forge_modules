/// tom_dart_editor_bundler — the single declaration of the generated layout.
///
/// Two parties have to agree on where a bundle set lives: the [BundleGenerator],
/// which writes the files, and the scope-init helper writer, which emits the
/// Flutter asset keys the app loads them by. When each states the arrangement in
/// its own code the two can drift, and the drift is silent — an asset key that
/// names nothing simply leaves the scope unregistered and the code field falls
/// back to plain text. So the arrangement is stated once, here, and both sides
/// derive from it.
///
/// The layout itself:
///
///   `<out-dir>/<sdk-summary>`        — one shared SDK summary (all scopes)
///   `<out-dir>/<name>/packages.sum`  — one grouped bundle per non-`sdk-only`
///                                      scope
///
/// It is expressed as *segments* rather than a joined string because the two
/// consumers need different joins: a Flutter asset key is always POSIX, while
/// the generator writes host paths. [assetKey] and [filePath] perform those two
/// joins over the same segment list.
library;

import 'package:path/path.dart' as p;

import 'bundler_config.dart';

/// Where a generated bundle set's files live, relative to the config's base
/// directory.
abstract final class SummaryAssetLayout {
  /// Filename of every non-`sdk-only` scope's grouped package bundle.
  static const String packagesFileName = 'packages.sum';

  /// Segments locating the shared SDK summary.
  static List<String> sdkSummarySegments(BundlerConfig config) =>
      [config.outDir, config.sdkSummary];

  /// Segments locating [bundle]'s grouped package bundle, or null when the
  /// scope is `sdk-only` — such a scope resolves SDK types only and has no
  /// `packages.sum` at all.
  static List<String>? packagesSegments(
    BundlerConfig config,
    SummaryBundleSpec bundle,
  ) =>
      bundle.sdkOnly
          ? null
          : [config.outDir, bundle.name, packagesFileName];

  /// [segments] as a Flutter asset key. Asset keys are POSIX regardless of the
  /// host OS, so a bundle generated on Windows is loadable by the same key.
  static String assetKey(List<String> segments) => segments
      .expand((segment) => segment.split(RegExp(r'[\\/]+')))
      .where((part) => part.isNotEmpty)
      .join('/');

  /// [segments] as a host filesystem path, resolved against [baseDir] when the
  /// configured `out-dir` is relative (it normally is; an absolute `out-dir` is
  /// honoured verbatim).
  static String filePath(String baseDir, List<String> segments) {
    final joined = p.joinAll(segments);
    return p.normalize(
      p.isAbsolute(joined) ? joined : p.join(baseDir, joined),
    );
  }
}

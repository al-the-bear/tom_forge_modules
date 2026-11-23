import 'dart:typed_data';

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/file_system/file_system.dart'
    show ResourceUriResolver;
import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import 'analyzer_with_packages.dart';

/// Immutable descriptor of a named summary scope (spec §6.4).
///
/// Produced by `tom_dart_editor_bundler`'s generated `SummaryScopes` helper:
/// each declared bundle becomes one `const SummaryScopeAsset` whose [name] is
/// the registry key, with the asset paths of its `.sum` files plus the editor
/// defaults (implicit imports, completion filters).
@immutable
class SummaryScopeAsset {
  /// Scope id — the registry key and the bundle name.
  final String name;

  /// Asset key of the shared SDK summary (`.sum`).
  final String sdkSummaryAsset;

  /// Asset key of the grouped package summary (`.sum`), or null for an
  /// SDK-only scope.
  final String? packageSummaryAsset;

  /// Imports auto-prepended to analysed snippets (drives baseline completions).
  final List<String> implicitImports;

  /// Optional completion filter applied to package libraries.
  final List<String> allowedPackagePrefixes;

  /// When true, completions are offered for all package libraries (subject to
  /// [allowedPackagePrefixes]), not only the implicitly imported ones.
  final bool includeAllPackageCompletions;

  const SummaryScopeAsset({
    required this.name,
    required this.sdkSummaryAsset,
    this.packageSummaryAsset,
    this.implicitImports = const [],
    this.allowedPackagePrefixes = const [],
    this.includeAllPackageCompletions = false,
  });
}

/// A registered scope: an immutable [asset] descriptor bound to its shared,
/// already-parsed [ParsedSummaryModel].
///
/// `tom_dart_editor` editors of the same scope all resolve to one [SummaryScope]
/// instance and build their own cheap [AnalysisDriverWithPackages] over the
/// single shared [model] (spec §3.1 memory goal).
class SummaryScope {
  /// The descriptor this scope was registered from.
  final SummaryScopeAsset asset;

  /// The shared parsed element model (one per scope, reused by every editor).
  final ParsedSummaryModel model;

  SummaryScope._(this.asset, this.model);

  /// Scope id.
  String get name => asset.name;

  /// Implicit imports for analysed snippets in this scope.
  List<String> get implicitImports => asset.implicitImports;

  /// Completion prefix filter for this scope.
  List<String> get allowedPackagePrefixes => asset.allowedPackagePrefixes;

  /// Whether all package libraries are offered for completion.
  bool get includeAllPackageCompletions => asset.includeAllPackageCompletions;

  /// Builds a fresh, lightweight analysis driver over the shared [model].
  ///
  /// Each editor calls this to get its own driver/controller without re-parsing
  /// the `.sum` bytes — the expensive parsed model is shared.
  ///
  /// [resourceProvider] is required, and deliberately has no default. A default
  /// here could only be a physical provider, which would make every caller that
  /// simply forgets the argument analyse against a real disk — silently, and
  /// correctly enough to pass its tests. Requiring it also keeps this library
  /// free of a direct `dart:io` reference — which is a readability property, not
  /// a platform one. Whether the package compiles for web is decided by a real
  /// `flutter build web`, not by which libraries are named here; see
  /// `test/web_build_test.dart`.
  ///
  /// The caller owns the filesystem decision; the production caller supplies an
  /// `OverlayResourceProvider` over a `MemoryResourceProvider`, so analysed
  /// source never leaves memory.
  AnalysisDriverWithPackages createDriver({
    required ResourceProvider resourceProvider,
  }) {
    return buildAnalysisDriver(
      model: model,
      resourceProvider: resourceProvider,
      uriResolvers: [ResourceUriResolver(resourceProvider)],
      packages: Packages.empty,
    );
  }
}

/// Loads the bytes of a Flutter asset by key. Injectable so tests can supply
/// bytes without a real asset bundle.
typedef SummaryAssetBytesLoader = Future<Uint8List> Function(String assetKey);

/// Process-wide, name-keyed registry of parsed summary scopes (spec §6.4).
///
/// `register(asset)` loads the `.sum` bytes (via [rootBundle] by default),
/// parses them into a shared [ParsedSummaryModel] (releasing the byte buffers),
/// and caches the scope by name. Registration is **idempotent and ref-aware**:
/// repeated calls for the same name reuse the one parsed model and bump a
/// reference count; [release] drops it when the last holder leaves. `scope(name)`
/// returns the handle, or null when the scope is unavailable (not registered).
class SummaryScopeRegistry {
  SummaryScopeRegistry._();

  /// The process-wide singleton.
  static final SummaryScopeRegistry instance = SummaryScopeRegistry._();

  final Map<String, _ScopeEntry> _entries = {};

  SummaryAssetBytesLoader _bytesLoader = _rootBundleBytesLoader;

  /// Overrides the asset byte loader (tests inject in-memory `.sum` bytes).
  @visibleForTesting
  set bytesLoader(SummaryAssetBytesLoader loader) => _bytesLoader = loader;

  /// Clears all registered scopes and restores the default loader (tests only).
  @visibleForTesting
  void resetForTesting() {
    _entries.clear();
    _bytesLoader = _rootBundleBytesLoader;
  }

  /// Whether a scope named [name] is currently registered.
  bool isRegistered(String name) => _entries.containsKey(name);

  /// The registered scope named [name], or null if unavailable.
  SummaryScope? scope(String name) => _entries[name]?.scope;

  /// The number of registered scopes.
  int get length => _entries.length;

  /// Registers [asset], returning its shared [SummaryScope].
  ///
  /// First registration loads + parses the `.sum` bytes; subsequent calls for
  /// the same [SummaryScopeAsset.name] reuse the parsed model and increment the
  /// reference count (no reload, no re-parse).
  Future<SummaryScope> register(SummaryScopeAsset asset) async {
    final existing = _entries[asset.name];
    if (existing != null) {
      existing.refCount++;
      return existing.scope;
    }

    final sdkBytes = await _bytesLoader(asset.sdkSummaryAsset);
    Uint8List? packageBytes;
    final packageAsset = asset.packageSummaryAsset;
    if (packageAsset != null && packageAsset.isNotEmpty) {
      packageBytes = await _bytesLoader(packageAsset);
    }

    final model = ParsedSummaryModel.fromSummaries(
      sdkSummaryBytes: sdkBytes,
      packageSummaryBytes: packageBytes,
    );

    // `sdkBytes` / `packageBytes` are method-locals; once this returns the
    // registry retains only `model` (no Uint8List field), so the raw buffers
    // are eligible for collection. N editors of this scope share one model.
    final scope = SummaryScope._(asset, model);
    _entries[asset.name] = _ScopeEntry(scope);
    return scope;
  }

  /// Releases one reference to the scope named [name]; the scope (and its parsed
  /// model) is dropped when the last reference is released. No-op if unknown.
  void release(String name) {
    final entry = _entries[name];
    if (entry == null) return;
    entry.refCount--;
    if (entry.refCount <= 0) {
      _entries.remove(name);
    }
  }
}

class _ScopeEntry {
  final SummaryScope scope;
  int refCount = 1;
  _ScopeEntry(this.scope);
}

Future<Uint8List> _rootBundleBytesLoader(String assetKey) async {
  final data = await rootBundle.load(assetKey);
  return data.buffer.asUint8List();
}

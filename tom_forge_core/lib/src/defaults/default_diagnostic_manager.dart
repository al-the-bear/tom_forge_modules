import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Default implementation of [ForgeDiagnosticCollection].
class DefaultDiagnosticCollection implements ForgeDiagnosticCollection {
  @override
  final String name;

  final Map<Uri, List<ForgeDiagnostic>> _diagnostics = {};
  final void Function() _onChanged;

  DefaultDiagnosticCollection({
    required this.name,
    required void Function() onChanged,
  }) : _onChanged = onChanged;

  @override
  void set(Uri uri, List<ForgeDiagnostic> diagnostics) {
    _diagnostics[uri] = List.unmodifiable(diagnostics);
    _onChanged();
  }

  @override
  void delete(Uri uri) {
    _diagnostics.remove(uri);
    _onChanged();
  }

  @override
  void clear() {
    _diagnostics.clear();
    _onChanged();
  }

  @override
  void dispose() {
    clear();
  }

  /// All diagnostics in this collection.
  Map<Uri, List<ForgeDiagnostic>> get diagnosticsByUri =>
      Map.unmodifiable(_diagnostics);

  /// Flat list of all diagnostics.
  List<ForgeDiagnostic> get allDiagnostics =>
      _diagnostics.values.expand((d) => d).toList();
}

/// Default implementation of [ForgeDiagnosticManager].
///
/// Manages multiple [DefaultDiagnosticCollection]s and aggregates
/// diagnostics for queries. Uses generation-based caching for per-URI
/// queries and debounced refresh for the aggregate list to handle
/// rapid updates efficiently (scalable to 10K+ diagnostics).
class DefaultDiagnosticManager implements ForgeDiagnosticManager {
  static bool debugEnabled = false;

  final List<DefaultDiagnosticCollection> _collections = [];
  final ForgeValueNotifier<List<ForgeDiagnostic>> _allNotifier =
      ForgeValueNotifier([]);

  /// Generation-based cache for per-URI diagnostic queries.
  final GenerationCache<Uri, List<ForgeDiagnostic>> _uriCache =
      GenerationCache();

  /// Debounce timer for batching rapid diagnostic updates.
  Timer? _refreshTimer;

  /// Debounce window for refresh coalescing.
  final Duration refreshDebounce;

  DefaultDiagnosticManager({
    this.refreshDebounce = const Duration(milliseconds: 100),
  });

  @override
  ForgeDiagnosticCollection createCollection(String name) {
    final collection = DefaultDiagnosticCollection(
      name: name,
      onChanged: _scheduleRefresh,
    );
    _collections.add(collection);
    return collection;
  }

  @override
  List<ForgeDiagnostic> get all => _allNotifier.value;

  @override
  List<ForgeDiagnostic> forUri(Uri uri) {
    // Use generation cache for per-URI lookups.
    final cached = _uriCache.get(uri);
    if (cached != null) return cached;

    final result = <ForgeDiagnostic>[];
    for (final collection in _collections) {
      final diags = collection.diagnosticsByUri[uri];
      if (diags != null) {
        result.addAll(diags);
      }
    }
    _uriCache.put(uri, result);
    return result;
  }

  /// Notifier for reactive UI updates.
  ForgeValueListenable<List<ForgeDiagnostic>> get allNotifier => _allNotifier;

  /// Schedule a debounced refresh. Rapid-fire collection changes are
  /// coalesced into a single list rebuild.
  ///
  /// When [refreshDebounce] is [Duration.zero], the refresh runs
  /// synchronously (useful for tests and small workspaces).
  void _scheduleRefresh() {
    _uriCache.invalidateAll();
    if (refreshDebounce == Duration.zero) {
      _refresh();
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = Timer(refreshDebounce, _refresh);
  }

  void _refresh() {
    final result = <ForgeDiagnostic>[];
    for (final collection in _collections) {
      result.addAll(collection.allDiagnostics);
    }
    _allNotifier.value = result;
    if (debugEnabled) {
      // ignore: avoid_print
      print('[DefaultDiagnosticManager] ${result.length} diagnostics');
    }
  }

  /// Dispose resources.
  void dispose() {
    _refreshTimer?.cancel();
    _allNotifier.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../services/forge_diagnostic_manager.dart';

/// Default implementation of [ForgeDiagnosticCollection].
class DefaultDiagnosticCollection implements ForgeDiagnosticCollection {
  @override
  final String name;

  final Map<Uri, List<ForgeDiagnostic>> _diagnostics = {};
  final VoidCallback _onChanged;

  DefaultDiagnosticCollection({
    required this.name,
    required VoidCallback onChanged,
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
/// diagnostics for queries.
class DefaultDiagnosticManager implements ForgeDiagnosticManager {
  static bool debugEnabled = false;

  final List<DefaultDiagnosticCollection> _collections = [];
  final ValueNotifier<List<ForgeDiagnostic>> _allNotifier =
      ValueNotifier([]);

  @override
  ForgeDiagnosticCollection createCollection(String name) {
    final collection = DefaultDiagnosticCollection(
      name: name,
      onChanged: _refresh,
    );
    _collections.add(collection);
    return collection;
  }

  @override
  List<ForgeDiagnostic> get all => _allNotifier.value;

  @override
  List<ForgeDiagnostic> forUri(Uri uri) {
    final result = <ForgeDiagnostic>[];
    for (final collection in _collections) {
      final diags = collection.diagnosticsByUri[uri];
      if (diags != null) {
        result.addAll(diags);
      }
    }
    return result;
  }

  /// Notifier for reactive UI updates.
  ValueListenable<List<ForgeDiagnostic>> get allNotifier => _allNotifier;

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
    _allNotifier.dispose();
  }
}

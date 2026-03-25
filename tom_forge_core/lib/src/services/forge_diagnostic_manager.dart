import 'package:tom_forge_core/tom_forge_core.dart';

/// Manages diagnostic collections from different sources.
abstract class ForgeDiagnosticManager {
  /// Create a named collection (e.g. 'dart-analyzer', 'yaml-validator').
  ForgeDiagnosticCollection createCollection(String name);

  /// All diagnostics across all collections.
  List<ForgeDiagnostic> get all;

  /// Diagnostics for a specific URI.
  List<ForgeDiagnostic> forUri(Uri uri);
}

/// A named set of diagnostics owned by a single source.
abstract class ForgeDiagnosticCollection {
  String get name;

  /// Set diagnostics for a URI (replaces previous).
  void set(Uri uri, List<ForgeDiagnostic> diagnostics);

  /// Remove diagnostics for a URI.
  void delete(Uri uri);

  /// Remove all diagnostics.
  void clear();

  /// Dispose and unregister this collection.
  void dispose();
}

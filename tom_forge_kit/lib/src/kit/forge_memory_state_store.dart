import 'dart:convert';

import 'forge_state_store.dart';

/// A [ForgeStateStore] in memory: for tests, and for hosts that persist the
/// documents elsewhere (they start it with [initial] and save [snapshot]).
///
/// Every document is copied as JSON on the way in and on the way out, so a
/// caller that changes a map after writing it, or a map it read, changes
/// nothing stored, and the values read back have the types a JSON decoder
/// gives (`Map<String, dynamic>`, `List<dynamic>`, int, double, ...) — the
/// same as from the file store. A document that is not JSON-compatible is
/// refused with the encoder's error.
class ForgeMemoryStateStore implements ForgeStateStore {
  /// A store holding [initial] (copied).
  ForgeMemoryStateStore({Map<String, Object?> initial = const {}}) {
    for (final entry in initial.entries) {
      if (entry.value != null) _documents[entry.key] = _copy(entry.value);
    }
  }

  final Map<String, Object?> _documents = {};

  /// The writes made, in order: the key and the document (null: removed).
  /// For tests that count what was written.
  final List<MapEntry<String, Object?>> writes = [];

  /// A copy of every document stored, by key.
  Map<String, Object?> snapshot() => {
    for (final entry in _documents.entries) entry.key: _copy(entry.value),
  };

  @override
  Future<Object?> read(String key) async => _copy(_documents[key]);

  @override
  Future<void> write(String key, Object? document) async {
    final copy = _copy(document);
    writes.add(MapEntry(key, copy));
    if (copy == null) {
      _documents.remove(key);
    } else {
      _documents[key] = copy;
    }
  }

  @override
  Future<List<String>> keys({String prefix = ''}) async => [
    for (final key in _documents.keys)
      if (key.startsWith(prefix)) key,
  ]..sort();

  @override
  Future<void> flushed() async {}

  static Object? _copy(Object? document) {
    if (document == null || document is String || document is bool) {
      return document;
    }
    if (document is num) return document;
    return jsonDecode(jsonEncode(document));
  }
}

/// A generation-based cache for expensive computations.
///
/// Each entry is tagged with the generation at which it was computed.
/// When the source data changes, bump the generation; stale entries are
/// automatically discarded on the next access. This avoids recomputing
/// values that haven't changed since the last generation.
class GenerationCache<K, V> {
  int _generation = 0;
  final Map<K, _GenerationEntry<V>> _entries = {};

  /// Current generation number.
  int get generation => _generation;

  /// Number of cached entries (including potentially stale ones).
  int get length => _entries.length;

  /// Bump the generation, invalidating all entries older than the new
  /// generation. Stale entries are lazily evicted on next [get].
  void invalidateAll() {
    _generation++;
  }

  /// Invalidate only entries for [key].
  void invalidate(K key) {
    _entries.remove(key);
  }

  /// Retrieve the cached value for [key] if it was computed at the
  /// current generation. Returns `null` for stale or missing entries.
  V? get(K key) {
    final entry = _entries[key];
    if (entry == null || entry.generation != _generation) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Store a value at the current generation.
  void put(K key, V value) {
    _entries[key] = _GenerationEntry(value: value, generation: _generation);
  }

  /// Get an existing value or compute and cache it.
  V getOrCompute(K key, V Function() compute) {
    final existing = get(key);
    if (existing != null) return existing;
    final value = compute();
    put(key, value);
    return value;
  }

  /// Remove all entries.
  void clear() {
    _entries.clear();
  }

  /// Remove stale entries from previous generations.
  void purgeStale() {
    _entries.removeWhere((_, entry) => entry.generation != _generation);
  }
}

class _GenerationEntry<V> {
  final V value;
  final int generation;

  _GenerationEntry({required this.value, required this.generation});
}

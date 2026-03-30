/// A generic capacity-limited Least-Recently-Used cache.
///
/// When the cache exceeds [maxEntries] or [maxSizeBytes] (if tracked),
/// the least recently accessed entry is evicted. Size tracking is opt-in
/// via the [sizeOf] callback.
class LruCache<K, V> {
  final int maxEntries;
  final int? maxSizeBytes;
  final int Function(K key, V value)? sizeOf;
  final void Function(K key, V value)? onEvicted;

  final _map = <K, V>{};
  int _currentSizeBytes = 0;

  LruCache({
    required this.maxEntries,
    this.maxSizeBytes,
    this.sizeOf,
    this.onEvicted,
  });

  /// Number of cached entries.
  int get length => _map.length;

  /// Current estimated size in bytes (0 if [sizeOf] not provided).
  int get currentSizeBytes => _currentSizeBytes;

  /// Whether the cache contains [key].
  bool containsKey(K key) => _map.containsKey(key);

  /// Retrieve a value, promoting it to most-recently-used.
  ///
  /// Returns `null` if the key is not present.
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // Re-insert at end (most recent).
    }
    return value;
  }

  /// Insert or update an entry, evicting LRU entries if limits exceeded.
  void put(K key, V value) {
    // If updating, remove old entry first.
    final existing = _map.remove(key);
    if (existing != null && sizeOf != null) {
      _currentSizeBytes -= sizeOf!(key, existing);
    }

    _map[key] = value;
    if (sizeOf != null) {
      _currentSizeBytes += sizeOf!(key, value);
    }

    _evictIfNeeded();
  }

  /// Remove a specific entry.
  V? remove(K key) {
    final value = _map.remove(key);
    if (value != null && sizeOf != null) {
      _currentSizeBytes -= sizeOf!(key, value);
    }
    return value;
  }

  /// Remove all entries.
  void clear() {
    _map.clear();
    _currentSizeBytes = 0;
  }

  /// All cached keys (oldest first).
  Iterable<K> get keys => _map.keys;

  /// All cached values (oldest first).
  Iterable<V> get values => _map.values;

  void _evictIfNeeded() {
    // Evict by entry count.
    while (_map.length > maxEntries) {
      _evictOldest();
    }
    // Evict by size budget.
    if (maxSizeBytes != null) {
      while (_currentSizeBytes > maxSizeBytes! && _map.isNotEmpty) {
        _evictOldest();
      }
    }
  }

  void _evictOldest() {
    final oldestKey = _map.keys.first;
    final oldestValue = _map.remove(oldestKey) as V;
    if (sizeOf != null) {
      _currentSizeBytes -= sizeOf!(oldestKey, oldestValue);
    }
    onEvicted?.call(oldestKey, oldestValue);
  }
}

import 'dart:typed_data';

import 'lru_cache.dart';

/// LRU cache for image preview data (e.g. decoded frames, thumbnails).
///
/// Bounded by both entry count ([maxEntries]) and total byte budget
/// ([maxSizeBytes], default 100 MB). When the budget is exceeded, the
/// least-recently-accessed image is evicted.
///
/// Usage:
/// ```dart
/// final cache = ImagePreviewCache();
/// cache.put(imageUri, bytes);
/// final cached = cache.get(imageUri);
/// ```
class ImagePreviewCache {
  late final LruCache<Uri, Uint8List> _cache;

  /// Current estimated size in bytes.
  int get currentSizeBytes => _cache.currentSizeBytes;

  /// Number of cached images.
  int get length => _cache.length;

  ImagePreviewCache({
    int maxEntries = 100,
    int maxSizeBytes = 100 * 1024 * 1024,
  }) {
    _cache = LruCache<Uri, Uint8List>(
      maxEntries: maxEntries,
      maxSizeBytes: maxSizeBytes,
      sizeOf: (_, bytes) => bytes.lengthInBytes,
    );
  }

  /// Retrieve cached image bytes, promoting to most-recently-used.
  Uint8List? get(Uri uri) => _cache.get(uri);

  /// Cache image bytes for a URI.
  void put(Uri uri, Uint8List bytes) => _cache.put(uri, bytes);

  /// Remove a specific cached image.
  void remove(Uri uri) => _cache.remove(uri);

  /// Whether [uri] is cached.
  bool containsKey(Uri uri) => _cache.containsKey(uri);

  /// Remove all cached images.
  void clear() => _cache.clear();
}

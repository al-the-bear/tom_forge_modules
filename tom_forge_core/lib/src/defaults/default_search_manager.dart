import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Default implementation of [ForgeSearchManager].
///
/// Searches across the in-memory file system entries.
/// Caches search results in an LRU cache bounded by [maxCacheEntries]
/// and [maxCacheSizeBytes]. Cache is invalidated when the file system
/// emits change events.
class DefaultSearchManager implements ForgeSearchManager {
  static bool debugEnabled = false;

  final MemoryFileSystem _fileSystem;

  /// LRU cache for search results, keyed by query fingerprint.
  final LruCache<String, List<ForgeSearchResult>> _cache;

  DefaultSearchManager({
    required MemoryFileSystem fileSystem,
    int maxCacheEntries = 200,
    int maxCacheSizeBytes = 50 * 1024 * 1024,
  })  : _fileSystem = fileSystem,
        _cache = LruCache(
          maxEntries: maxCacheEntries,
          maxSizeBytes: maxCacheSizeBytes,
          sizeOf: (_, results) => results.fold<int>(
            0,
            (sum, r) =>
                sum +
                r.matches.fold<int>(
                    0, (ms, m) => ms + m.lineText.length * 2),
          ),
        );

  /// Clear the search result cache.
  void clearCache() => _cache.clear();

  /// Build a cache key from the search parameters.
  String _cacheKey(
    String query, {
    required bool isRegExp,
    required bool isCaseSensitive,
    required bool isWordMatch,
    String? includePattern,
    String? excludePattern,
    int? maxResults,
  }) =>
      '$query|$isRegExp|$isCaseSensitive|$isWordMatch|'
      '$includePattern|$excludePattern|$maxResults';

  @override
  Future<List<ForgeSearchResult>> search(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
    int? maxResults,
  }) async {
    try {
      final key = _cacheKey(
        query,
        isRegExp: isRegExp,
        isCaseSensitive: isCaseSensitive,
        isWordMatch: isWordMatch,
        includePattern: includePattern,
        excludePattern: excludePattern,
        maxResults: maxResults,
      );

      final cached = _cache.get(key);
      if (cached != null) return cached;

      final results = <ForgeSearchResult>[];
      final pattern = _buildPattern(
        query,
        isRegExp: isRegExp,
        isCaseSensitive: isCaseSensitive,
        isWordMatch: isWordMatch,
      );

      for (final path in _fileSystem.paths) {
        final uri = Uri.parse('file://$path');
        if (!_matchesFilter(uri, includePattern, excludePattern)) continue;

        final content = await _fileSystem.read(uri);
        final matches = _findMatches(content, pattern);
        if (matches.isNotEmpty) {
          results.add(ForgeSearchResult(uri: uri, matches: matches));
          if (maxResults != null && results.length >= maxResults) break;
        }
      }

      _cache.put(key, results);
      return results;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultSearchManager] search error: $e');
      }
      return [];
    }
  }

  @override
  Stream<ForgeSearchResult> searchStream(
    String query, {
    bool isRegExp = false,
    bool isCaseSensitive = false,
    bool isWordMatch = false,
    String? includePattern,
    String? excludePattern,
  }) async* {
    try {
      final pattern = _buildPattern(
        query,
        isRegExp: isRegExp,
        isCaseSensitive: isCaseSensitive,
        isWordMatch: isWordMatch,
      );

      for (final path in _fileSystem.paths) {
        final uri = Uri.parse('file://$path');
        if (!_matchesFilter(uri, includePattern, excludePattern)) continue;

        final content = await _fileSystem.read(uri);
        final matches = _findMatches(content, pattern);
        if (matches.isNotEmpty) {
          yield ForgeSearchResult(uri: uri, matches: matches);
        }
      }
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultSearchManager] searchStream error: $e');
      }
    }
  }

  RegExp _buildPattern(
    String query, {
    required bool isRegExp,
    required bool isCaseSensitive,
    required bool isWordMatch,
  }) {
    var pattern = isRegExp ? query : RegExp.escape(query);
    if (isWordMatch) {
      pattern = '\\b$pattern\\b';
    }
    return RegExp(pattern, caseSensitive: isCaseSensitive);
  }

  List<ForgeSearchMatch> _findMatches(String content, RegExp pattern) {
    final matches = <ForgeSearchMatch>[];
    final lines = content.split('\n');

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      for (final match in pattern.allMatches(line)) {
        matches.add(ForgeSearchMatch(
          range: ForgeTextRange(
            start: ForgeTextPosition(line: lineIdx, column: match.start),
            end: ForgeTextPosition(line: lineIdx, column: match.end),
          ),
          lineText: line,
        ));
      }
    }
    return matches;
  }

  bool _matchesFilter(
    Uri uri,
    String? includePattern,
    String? excludePattern,
  ) {
    final path = uri.path;
    if (includePattern != null && !path.contains(includePattern)) return false;
    if (excludePattern != null && path.contains(excludePattern)) return false;
    return true;
  }
}

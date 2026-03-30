import 'dart:async';
import 'dart:io';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Search manager implementation that uses a real file system.
///
/// Performs text search across files in the workspace directory.
/// Caches search results in an LRU cache bounded by entry count and
/// estimated size. Cache is keyed by query parameters.
class RealSearchManager implements ForgeSearchManager {
  final Directory rootDirectory;

  /// LRU cache for search results, keyed by query fingerprint.
  final LruCache<String, List<ForgeSearchResult>> _cache;

  RealSearchManager({
    required this.rootDirectory,
    int maxCacheEntries = 200,
    int maxCacheSizeBytes = 50 * 1024 * 1024,
  }) : _cache = LruCache(
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

    await _searchDirectory(
      rootDirectory,
      pattern,
      results,
      includePattern: includePattern,
      excludePattern: excludePattern,
      maxResults: maxResults,
    );

    _cache.put(key, results);
    return results;
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
    final pattern = _buildPattern(
      query,
      isRegExp: isRegExp,
      isCaseSensitive: isCaseSensitive,
      isWordMatch: isWordMatch,
    );

    await for (final result in _searchDirectoryStream(
      rootDirectory,
      pattern,
      includePattern: includePattern,
      excludePattern: excludePattern,
    )) {
      yield result;
    }
  }

  Stream<ForgeSearchResult> _searchDirectoryStream(
    Directory dir,
    RegExp pattern, {
    String? includePattern,
    String? excludePattern,
  }) async* {
    await for (final entity in dir.list(followLinks: false)) {
      final name = entity.path.split('/').last;

      // Skip hidden files and common excluded directories
      if (name.startsWith('.') ||
          name == 'node_modules' ||
          name == 'build' ||
          name == '.dart_tool') {
        continue;
      }

      if (entity is Directory) {
        await for (final result in _searchDirectoryStream(
          entity,
          pattern,
          includePattern: includePattern,
          excludePattern: excludePattern,
        )) {
          yield result;
        }
      } else if (entity is File) {
        // Apply include/exclude patterns
        if (includePattern != null &&
            !_matchesGlob(entity.path, includePattern)) {
          continue;
        }
        if (excludePattern != null &&
            _matchesGlob(entity.path, excludePattern)) {
          continue;
        }

        final result = await _searchFile(entity, pattern);
        if (result != null) {
          yield result;
        }
      }
    }
  }

  Future<void> _searchDirectory(
    Directory dir,
    RegExp pattern,
    List<ForgeSearchResult> results, {
    String? includePattern,
    String? excludePattern,
    int? maxResults,
  }) async {
    if (maxResults != null && results.length >= maxResults) return;

    await for (final entity in dir.list(followLinks: false)) {
      if (maxResults != null && results.length >= maxResults) break;

      final name = entity.path.split('/').last;

      // Skip hidden files and common excluded directories
      if (name.startsWith('.') ||
          name == 'node_modules' ||
          name == 'build' ||
          name == '.dart_tool') {
        continue;
      }

      if (entity is Directory) {
        await _searchDirectory(
          entity,
          pattern,
          results,
          includePattern: includePattern,
          excludePattern: excludePattern,
          maxResults: maxResults,
        );
      } else if (entity is File) {
        // Apply include/exclude patterns
        if (includePattern != null &&
            !_matchesGlob(entity.path, includePattern)) {
          continue;
        }
        if (excludePattern != null &&
            _matchesGlob(entity.path, excludePattern)) {
          continue;
        }

        final result = await _searchFile(entity, pattern);
        if (result != null) {
          results.add(result);
        }
      }
    }
  }

  Future<ForgeSearchResult?> _searchFile(
    File file,
    RegExp pattern,
  ) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');
      final uri = Uri.file(file.path);
      final matches = <ForgeSearchMatch>[];

      for (var lineNum = 0; lineNum < lines.length; lineNum++) {
        final line = lines[lineNum];
        final lineMatches = pattern.allMatches(line);

        for (final match in lineMatches) {
          matches.add(ForgeSearchMatch(
            range: ForgeTextRange(
              start: ForgeTextPosition(line: lineNum, column: match.start),
              end: ForgeTextPosition(line: lineNum, column: match.end),
            ),
            lineText: line,
          ));
        }
      }

      if (matches.isNotEmpty) {
        return ForgeSearchResult(uri: uri, matches: matches);
      }
      return null;
    } catch (e) {
      // Skip files that can't be read as text (binary files)
      return null;
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

  bool _matchesGlob(String path, String pattern) {
    // Simple glob matching - convert to regex
    final regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('*', '.*')
        .replaceAll('?', '.');
    return RegExp(regexPattern).hasMatch(path);
  }
}

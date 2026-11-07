import 'dart:async';
import 'dart:convert';

import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_file_system/tom_file_system.dart';

/// Default implementation of [ForgeSearchManager], over any [TomFileSystem]
/// — the local disk, memory, the web.
///
/// Searches the text files under the file system's root: folders of build
/// output, tools and version control ([skippedFolderNames]) are not entered,
/// a file over [maxFileSizeBytes] or one whose start does not look like text
/// (`tomLooksLikeText`) is not read, and a file that cannot be read is passed
/// over without ending the search.
/// Caches search results in an LRU cache bounded by [maxCacheEntries]
/// and [maxCacheSizeBytes]. Cache is invalidated when the file system
/// emits change events.
class DefaultSearchManager implements ForgeSearchManager {
  static bool debugEnabled = false;

  /// Files larger than this are not searched.
  static const int maxFileSizeBytes = 2 * 1024 * 1024;

  /// Folders never searched: build output, tool state, version control.
  static const Set<String> skippedFolderNames = {
    'node_modules',
    'build',
    '.dart_tool',
    '.git',
    '.svn',
    '.hg',
    '__pycache__',
    '.gradle',
    '.idea',
    'coverage',
    '.pub-cache',
  };

  final TomFileSystem _fileSystem;

  /// LRU cache for search results, keyed by query fingerprint.
  final LruCache<String, List<ForgeSearchResult>> _cache;

  DefaultSearchManager({
    required TomFileSystem fileSystem,
    int maxCacheEntries = 200,
    int maxCacheSizeBytes = 50 * 1024 * 1024,
  }) : _fileSystem = fileSystem,
       _cache = LruCache(
         maxEntries: maxCacheEntries,
         maxSizeBytes: maxCacheSizeBytes,
         sizeOf: (_, results) => results.fold<int>(
           0,
           (sum, r) =>
               sum +
               r.matches.fold<int>(0, (ms, m) => ms + m.lineText.length * 2),
         ),
       );

  /// Every file under the root, in path order; a link that leaves the root
  /// is not followed.
  Stream<Uri> _files() async* {
    final files = <TomFileEntry>[];
    final pending = [_fileSystem.root];
    while (pending.isNotEmpty) {
      final List<TomFileEntry> entries;
      try {
        entries = await _fileSystem.list(pending.removeLast());
      } on Exception {
        continue; // An unreadable folder does not end the search.
      }
      for (final entry in entries) {
        if (!entry.isDirectory) {
          if (entry.size <= maxFileSizeBytes) files.add(entry);
        } else if (entry.expandable &&
            !skippedFolderNames.contains(entry.name)) {
          pending.add(entry.uri);
        }
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      yield file.uri;
    }
  }

  /// The text of [uri], or null when it is not text or cannot be read.
  Future<String?> _textOf(Uri uri) async {
    try {
      final bytes = (await _fileSystem.read(uri)).bytes;
      if (!tomLooksLikeText(
        bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes,
      )) {
        return null;
      }
      return utf8.decode(bytes);
    } on Exception {
      return null;
    }
  }

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

      await for (final uri in _files()) {
        if (!_matchesFilter(uri, includePattern, excludePattern)) continue;

        final content = await _textOf(uri);
        if (content == null) continue;
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

      await for (final uri in _files()) {
        if (!_matchesFilter(uri, includePattern, excludePattern)) continue;

        final content = await _textOf(uri);
        if (content == null) continue;
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
        matches.add(
          ForgeSearchMatch(
            range: ForgeTextRange(
              start: ForgeTextPosition(line: lineIdx, column: match.start),
              end: ForgeTextPosition(line: lineIdx, column: match.end),
            ),
            lineText: line,
          ),
        );
      }
    }
    return matches;
  }

  bool _matchesFilter(Uri uri, String? includePattern, String? excludePattern) {
    final path = uri.path;
    if (includePattern != null && !path.contains(includePattern)) return false;
    if (excludePattern != null && path.contains(excludePattern)) return false;
    return true;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

/// Search manager implementation that uses a real file system.
///
/// Performs text search across files in the workspace directory.
/// Caches search results in an LRU cache bounded by entry count and
/// estimated size. Cache is keyed by query parameters.
///
/// Features:
/// - Binary file detection by extension (skips images, fonts, archives, etc.)
/// - Maximum file size guard (skips files larger than 2 MB)
/// - Comprehensive directory exclusion (build, .git, node_modules, etc.)
/// - Error-resilient directory traversal (bad dirs don't kill the search)
class RealSearchManager implements ForgeSearchManager {
  final Directory rootDirectory;

  /// LRU cache for search results, keyed by query fingerprint.
  final LruCache<String, List<ForgeSearchResult>> _cache;

  /// File extensions known to be binary (not searchable as text).
  static const _binaryExtensions = <String>{
    // Images
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.webp', '.tiff',
    '.psd', '.raw', '.cr2', '.nef',
    // Fonts
    '.ttf', '.otf', '.woff', '.woff2', '.eot',
    // Archives
    '.zip', '.tar', '.gz', '.bz2', '.7z', '.rar', '.xz', '.zst',
    // Documents (binary)
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    // Executables and libraries
    '.exe', '.dll', '.so', '.dylib', '.class', '.jar', '.dex',
    '.o', '.a', '.lib', '.obj',
    // Media
    '.mp3', '.mp4', '.avi', '.mkv', '.wav', '.flac', '.ogg', '.mov',
    '.wmv', '.aac', '.m4a',
    // Dart/Flutter specific binary
    '.dill', '.snapshot',
    // Database
    '.db', '.sqlite', '.sqlite3',
  };

  /// Maximum file size to search (skip larger files).
  static const _maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB

  /// Directories to always skip during workspace search.
  static const _skipDirectoryNames = <String>{
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
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
  };

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

    yield* _searchDirectoryStream(
      rootDirectory,
      pattern,
      includePattern: includePattern,
      excludePattern: excludePattern,
    );
  }

  Stream<ForgeSearchResult> _searchDirectoryStream(
    Directory dir,
    RegExp pattern, {
    String? includePattern,
    String? excludePattern,
  }) async* {
    List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } catch (e) {
      // Skip directories that cannot be listed (permissions, broken links).
      debugPrint('[RealSearchManager] Cannot list ${dir.path}: $e');
      return;
    }

    for (final entity in entries) {
      final name = entity.path.split('/').last;

      // Skip hidden files/dirs and known non-searchable directories.
      if (name.startsWith('.') || _skipDirectoryNames.contains(name)) {
        continue;
      }

      if (entity is Directory) {
        yield* _searchDirectoryStream(
          entity,
          pattern,
          includePattern: includePattern,
          excludePattern: excludePattern,
        );
      } else if (entity is File) {
        if (_shouldSkipFile(entity, includePattern, excludePattern)) continue;

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

    List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } catch (e) {
      // Skip directories that cannot be listed (permissions, broken links).
      debugPrint('[RealSearchManager] Cannot list ${dir.path}: $e');
      return;
    }

    for (final entity in entries) {
      if (maxResults != null && results.length >= maxResults) break;

      final name = entity.path.split('/').last;

      // Skip hidden files/dirs and known non-searchable directories.
      if (name.startsWith('.') || _skipDirectoryNames.contains(name)) {
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
        if (_shouldSkipFile(entity, includePattern, excludePattern)) continue;

        final result = await _searchFile(entity, pattern);
        if (result != null) {
          results.add(result);
        }
      }
    }
  }

  /// Returns true if the file should be skipped based on extension,
  /// size, or include/exclude patterns.
  bool _shouldSkipFile(
    File file,
    String? includePattern,
    String? excludePattern,
  ) {
    final path = file.path;
    final ext = _fileExtension(path);

    // Skip known binary file extensions.
    if (_binaryExtensions.contains(ext)) return true;

    // Apply include/exclude patterns.
    if (includePattern != null && !_matchesGlob(path, includePattern)) {
      return true;
    }
    if (excludePattern != null && _matchesGlob(path, excludePattern)) {
      return true;
    }

    return false;
  }

  /// Extracts the lowercase file extension (e.g., '.dart').
  static String _fileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    final lastSlash = path.lastIndexOf('/');
    if (lastDot < 0 || lastDot < lastSlash) return '';
    return path.substring(lastDot).toLowerCase();
  }

  Future<ForgeSearchResult?> _searchFile(
    File file,
    RegExp pattern,
  ) async {
    try {
      // Check file size before reading to avoid loading huge files.
      final stat = await file.stat();
      if (stat.size > _maxFileSizeBytes) return null;

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
      // Skip files that can't be read as text (binary files, permission issues).
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
    // Simple glob matching - convert glob to regex.
    final regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('**', '\x00') // Temp marker for **
        .replaceAll('*', r'[^/]*')
        .replaceAll('\x00', '.*') // ** matches across directories
        .replaceAll('?', '.');
    return RegExp(regexPattern).hasMatch(path);
  }
}

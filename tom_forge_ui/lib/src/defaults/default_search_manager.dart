import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

import 'memory_file_system.dart';

/// Default implementation of [ForgeSearchManager].
///
/// Searches across the in-memory file system entries.
class DefaultSearchManager implements ForgeSearchManager {
  static bool debugEnabled = false;

  final MemoryFileSystem _fileSystem;

  DefaultSearchManager({required MemoryFileSystem fileSystem})
      : _fileSystem = fileSystem;

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

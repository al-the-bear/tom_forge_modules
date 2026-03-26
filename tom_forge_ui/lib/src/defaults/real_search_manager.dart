import 'dart:async';
import 'dart:io';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Search manager implementation that uses a real file system.
///
/// Performs text search across files in the workspace directory.
class RealSearchManager implements ForgeSearchManager {
  final Directory rootDirectory;

  RealSearchManager({required this.rootDirectory});

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

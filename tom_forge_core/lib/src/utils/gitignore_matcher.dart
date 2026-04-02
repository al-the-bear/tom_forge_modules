import 'dart:io';

/// Parses `.gitignore` files and matches paths against the collected rules.
///
/// Supports standard gitignore syntax:
/// - Blank lines and comment lines (starting with `#`) are ignored.
/// - Trailing spaces are trimmed unless escaped with `\`.
/// - A leading `!` negates the pattern (re-includes a previously ignored path).
/// - A trailing `/` matches only directories.
/// - Patterns without `/` are matched against the file name only.
/// - Patterns with `/` (other than trailing) are matched against the
///   path relative to the `.gitignore` location.
/// - `*` matches anything except `/`.
/// - `**` matches zero or more directories.
/// - `?` matches any single character except `/`.
///
/// Usage:
/// ```dart
/// final matcher = GitIgnoreMatcher();
/// await matcher.loadFromRoot('/path/to/workspace');
/// if (matcher.isIgnored('/path/to/workspace/build/output.js', isDirectory: false)) {
///   // skip this file
/// }
/// ```
class GitIgnoreMatcher {
  final List<_GitIgnoreFile> _ignoreFiles = [];

  /// Loads all `.gitignore` files found under [rootPath] (recursively).
  ///
  /// The root `.gitignore` is loaded first, then nested ones in directory
  /// order so that rules closer to a file take precedence.
  Future<void> loadFromRoot(String rootPath) async {
    _ignoreFiles.clear();
    final normalizedRoot = _normalizePath(rootPath);
    await _loadRecursive(Directory(normalizedRoot), normalizedRoot);
  }

  Future<void> _loadRecursive(Directory dir, String rootPath) async {
    final gitignoreFile = File('${dir.path}/.gitignore');
    if (gitignoreFile.existsSync()) {
      try {
        final content = await gitignoreFile.readAsString();
        final relativeDirPath = dir.path == rootPath
            ? ''
            : dir.path.substring(rootPath.length + 1);
        _ignoreFiles.add(_GitIgnoreFile.parse(content, relativeDirPath));
      } catch (_) {
        // Unreadable .gitignore — skip silently.
      }
    }

    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.uri.pathSegments
              .lastWhere((s) => s.isNotEmpty, orElse: () => '');
          // Never recurse into .git itself.
          if (name == '.git') continue;
          // Skip directories that are already ignored — avoids unnecessary I/O.
          final relPath = entity.path.substring(rootPath.length + 1);
          if (isIgnored(relPath, isDirectory: true)) continue;
          await _loadRecursive(entity, rootPath);
        }
      }
    } catch (_) {
      // Permission errors etc. — skip silently.
    }
  }

  /// Returns `true` if [relativePath] is ignored by the collected rules.
  ///
  /// [relativePath] must be relative to the workspace root (no leading `/`).
  /// Set [isDirectory] to `true` when the path refers to a directory.
  bool isIgnored(String relativePath, {required bool isDirectory}) {
    // Normalize to forward slashes.
    final path = relativePath.replaceAll('\\', '/');
    if (path.isEmpty) return false;

    // Evaluate all ignore files. Later rules override earlier ones;
    // a negated rule can un-ignore a file.
    bool? ignored;
    for (final ignoreFile in _ignoreFiles) {
      final result = ignoreFile.match(path, isDirectory: isDirectory);
      if (result != null) {
        ignored = result;
      }
    }
    return ignored ?? false;
  }

  /// Clears all loaded rules.
  void clear() => _ignoreFiles.clear();

  static String _normalizePath(String path) {
    // Remove trailing slash.
    if (path.endsWith('/') || path.endsWith('\\')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }
}

/// A single parsed `.gitignore` file with its rules.
class _GitIgnoreFile {
  final String directoryPrefix;
  final List<_GitIgnoreRule> rules;

  _GitIgnoreFile(this.directoryPrefix, this.rules);

  /// Parses gitignore content into rules.
  factory _GitIgnoreFile.parse(String content, String directoryPrefix) {
    final rules = <_GitIgnoreRule>[];
    for (final rawLine in content.split('\n')) {
      final line = _trimTrailingSpaces(rawLine);
      if (line.isEmpty || line.startsWith('#')) continue;
      rules.add(_GitIgnoreRule.parse(line, directoryPrefix));
    }
    return _GitIgnoreFile(directoryPrefix, rules);
  }

  /// Matches [relativePath] against all rules in this file.
  ///
  /// Returns `true` if ignored, `false` if negated, or `null` if no rule
  /// matches.
  bool? match(String relativePath, {required bool isDirectory}) {
    bool? result;
    for (final rule in rules) {
      final matches = rule.matches(relativePath, isDirectory: isDirectory);
      if (matches) {
        result = !rule.negated;
      }
    }
    return result;
  }

  static String _trimTrailingSpaces(String line) {
    // Trailing spaces are ignored unless escaped with backslash.
    var i = line.length;
    while (i > 0 && line[i - 1] == ' ') {
      if (i >= 2 && line[i - 2] == '\\') break;
      i--;
    }
    return line.substring(0, i);
  }
}

/// A single gitignore rule with a compiled regex.
class _GitIgnoreRule {
  final bool negated;
  final bool directoryOnly;
  final RegExp _pattern;

  _GitIgnoreRule({
    required this.negated,
    required this.directoryOnly,
    required RegExp pattern,
  }) : _pattern = pattern;

  factory _GitIgnoreRule.parse(String line, String directoryPrefix) {
    var pattern = line;
    var negated = false;
    var directoryOnly = false;

    // Handle negation.
    if (pattern.startsWith('!')) {
      negated = true;
      pattern = pattern.substring(1);
    }

    // Handle directory-only marker.
    if (pattern.endsWith('/')) {
      directoryOnly = true;
      pattern = pattern.substring(0, pattern.length - 1);
    }

    // Handle leading slash — anchored to the gitignore's directory.
    var anchored = false;
    if (pattern.startsWith('/')) {
      anchored = true;
      pattern = pattern.substring(1);
    }

    // If the pattern contains a slash (other than the ones we stripped),
    // it is path-relative and thus anchored.
    if (pattern.contains('/')) {
      anchored = true;
    }

    // Build the regex from the glob pattern.
    final regexStr = _globToRegex(pattern);

    final String fullRegex;
    if (anchored) {
      // Match relative to the .gitignore directory.
      if (directoryPrefix.isEmpty) {
        fullRegex = '^$regexStr';
      } else {
        final escapedPrefix = RegExp.escape(directoryPrefix);
        fullRegex = '^$escapedPrefix/$regexStr';
      }
    } else {
      // Match against any path component — the pattern can appear anywhere
      // after a `/` or at the start.
      fullRegex = '(^|/)$regexStr';
    }

    return _GitIgnoreRule(
      negated: negated,
      directoryOnly: directoryOnly,
      pattern: RegExp(fullRegex),
    );
  }

  bool matches(String relativePath, {required bool isDirectory}) {
    if (directoryOnly && !isDirectory) return false;
    // For directory-only rules, also match files *inside* the directory.
    if (_pattern.hasMatch(relativePath)) return true;
    // Check if the path is *inside* a matched directory.
    // e.g. rule "build" should match "build/output.js".
    if (!directoryOnly) {
      // Non-directory rules also match files by name at the end of the path.
      final name = relativePath.contains('/')
          ? relativePath.substring(relativePath.lastIndexOf('/') + 1)
          : relativePath;
      if (_pattern.hasMatch(name)) return true;
    }
    return false;
  }

  /// Converts a gitignore glob pattern to a regex string.
  static String _globToRegex(String glob) {
    final buf = StringBuffer();
    var i = 0;
    while (i < glob.length) {
      final ch = glob[i];
      switch (ch) {
        case '*':
          if (i + 1 < glob.length && glob[i + 1] == '*') {
            // ** — matches everything including path separators.
            if (i + 2 < glob.length && glob[i + 2] == '/') {
              // **/ matches zero or more directories.
              buf.write('(.+/)?');
              i += 3;
            } else {
              buf.write('.*');
              i += 2;
            }
          } else {
            // * matches anything except /.
            buf.write('[^/]*');
            i++;
          }
        case '?':
          buf.write('[^/]');
          i++;
        case '[':
          // Character class — pass through until `]`.
          final end = glob.indexOf(']', i);
          if (end == -1) {
            buf.write(RegExp.escape(ch));
            i++;
          } else {
            buf.write(glob.substring(i, end + 1));
            i = end + 1;
          }
        case '\\':
          // Escaped character.
          if (i + 1 < glob.length) {
            buf.write(RegExp.escape(glob[i + 1]));
            i += 2;
          } else {
            buf.write(RegExp.escape(ch));
            i++;
          }
        default:
          buf.write(RegExp.escape(ch));
          i++;
      }
    }
    // Allow matching entire directory trees.
    buf.write('(/.*)?');
    buf.write(r'$');
    return buf.toString();
  }
}

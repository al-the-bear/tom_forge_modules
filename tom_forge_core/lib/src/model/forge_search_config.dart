/// Configuration for the quick-open file search.
///
/// Controls which files and directories are searched, size limits,
/// and default exclusion behaviors.
class ForgeSearchConfig {
  /// File extensions to exclude from search results (without leading dot).
  ///
  /// Example: `{'png', 'jpg', 'exe', 'o', 'class', 'lock'}`.
  final Set<String> excludedExtensions;

  /// Directory names to exclude from search.
  ///
  /// Matched against individual path segments (not full paths).
  /// Example: `{'node_modules', 'build', '.dart_tool'}`.
  final Set<String> excludedDirectories;

  /// Maximum file size in bytes. Files larger than this are skipped.
  ///
  /// Defaults to 10 MB.
  final int fileSizeLimit;

  /// Whether to skip directories whose name starts with a dot.
  final bool excludeHiddenDirectories;

  /// Whether to honour `.gitignore` rules when searching.
  final bool excludeGitIgnored;

  /// Maximum number of file results to return per search.
  final int maxFileResults;

  /// Creates a search configuration with sensible defaults.
  const ForgeSearchConfig({
    this.excludedExtensions = const {
      // Images / media.
      'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico', 'svg',
      'mp3', 'mp4', 'wav', 'avi', 'mov',
      // Compiled / binary.
      'exe', 'dll', 'so', 'dylib', 'o', 'a', 'class', 'pyc',
      'dill', 'aot',
      // Archives.
      'zip', 'tar', 'gz', 'bz2', 'xz', '7z', 'rar',
      // Lock / generated.
      'lock', 'g.dart',
    },
    this.excludedDirectories = const {
      'node_modules',
      'build',
      '.dart_tool',
      '.git',
      '.idea',
      '.vscode',
      '__pycache__',
    },
    this.fileSizeLimit = 10 * 1024 * 1024,
    this.excludeHiddenDirectories = true,
    this.excludeGitIgnored = true,
    this.maxFileResults = 50,
  });

  /// Creates a copy with selected fields replaced.
  ForgeSearchConfig copyWith({
    Set<String>? excludedExtensions,
    Set<String>? excludedDirectories,
    int? fileSizeLimit,
    bool? excludeHiddenDirectories,
    bool? excludeGitIgnored,
    int? maxFileResults,
  }) {
    return ForgeSearchConfig(
      excludedExtensions: excludedExtensions ?? this.excludedExtensions,
      excludedDirectories: excludedDirectories ?? this.excludedDirectories,
      fileSizeLimit: fileSizeLimit ?? this.fileSizeLimit,
      excludeHiddenDirectories:
          excludeHiddenDirectories ?? this.excludeHiddenDirectories,
      excludeGitIgnored: excludeGitIgnored ?? this.excludeGitIgnored,
      maxFileResults: maxFileResults ?? this.maxFileResults,
    );
  }

  /// Serialises this configuration to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'excludedExtensions': excludedExtensions.toList()..sort(),
      'excludedDirectories': excludedDirectories.toList()..sort(),
      'fileSizeLimit': fileSizeLimit,
      'excludeHiddenDirectories': excludeHiddenDirectories,
      'excludeGitIgnored': excludeGitIgnored,
      'maxFileResults': maxFileResults,
    };
  }

  /// Deserialises a configuration from a JSON-compatible map.
  factory ForgeSearchConfig.fromJson(Map<String, dynamic> json) {
    return ForgeSearchConfig(
      excludedExtensions: _setFromJson(json['excludedExtensions']),
      excludedDirectories: _setFromJson(json['excludedDirectories']),
      fileSizeLimit: json['fileSizeLimit'] as int? ?? 10 * 1024 * 1024,
      excludeHiddenDirectories:
          json['excludeHiddenDirectories'] as bool? ?? true,
      excludeGitIgnored: json['excludeGitIgnored'] as bool? ?? true,
      maxFileResults: json['maxFileResults'] as int? ?? 50,
    );
  }

  static Set<String> _setFromJson(dynamic value) {
    if (value is List) {
      return value.cast<String>().toSet();
    }
    return const {};
  }

  /// Returns `true` if the given file extension (without dot) should be
  /// excluded.
  bool isExtensionExcluded(String extension) {
    return excludedExtensions.contains(extension.toLowerCase());
  }

  /// Returns `true` if the given directory name should be excluded.
  bool isDirectoryExcluded(String directoryName) {
    if (excludedDirectories.contains(directoryName)) return true;
    if (excludeHiddenDirectories && directoryName.startsWith('.')) return true;
    return false;
  }
}

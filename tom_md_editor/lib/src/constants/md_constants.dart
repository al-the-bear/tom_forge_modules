/// Constants used across the markdown editor package.
class MdConstants {
  MdConstants._();

  // ── Layout defaults ──

  static const double defaultTreePanelRatio = 0.25;
  static const double defaultRawEditorHeightRatio = 0.35;
  static const double defaultRawEditorWidthRatio = 0.4;
  static const double defaultSearchResultsHeightRatio = 0.5;

  // ── Timing ──

  static const int defaultLivePreviewDebounceMs = 300;
  static const int defaultAutoSaveDebounceMs = 2000;
  static const int defaultMaxUndoHistory = 100;

  // ── Supported code-block languages ──

  static const Map<String, List<String>> languageAliases = {
    'dart': ['dart'],
    'javascript': ['js', 'javascript'],
    'typescript': ['ts', 'typescript'],
    'python': ['py', 'python'],
    'java': ['java'],
    'kotlin': ['kt', 'kotlin'],
    'swift': ['swift'],
    'c': ['c'],
    'cpp': ['cpp', 'c++'],
    'csharp': ['cs', 'csharp'],
    'go': ['go', 'golang'],
    'rust': ['rs', 'rust'],
    'ruby': ['rb', 'ruby'],
    'php': ['php'],
    'sql': ['sql'],
    'html': ['html'],
    'css': ['css'],
    'scss': ['scss', 'sass'],
    'json': ['json'],
    'yaml': ['yaml', 'yml'],
    'xml': ['xml'],
    'markdown': ['md', 'markdown'],
    'shell': ['sh', 'bash', 'zsh', 'shell'],
    'powershell': ['ps', 'powershell'],
    'dockerfile': ['dockerfile'],
    'plaintext': ['text', 'plaintext'],
  };

  /// Resolves an alias (e.g. `'js'`) to its canonical language name.
  static String resolveLanguage(String? alias) {
    if (alias == null || alias.isEmpty) return 'plaintext';
    final lower = alias.toLowerCase();
    for (final entry in languageAliases.entries) {
      if (entry.value.contains(lower)) return entry.key;
    }
    return lower;
  }

  // ── Schema detection pattern ──

  /// Regex to detect `<!-- schema=<id> -->` in the first heading.
  static final RegExp schemaPattern = RegExp(
    r'<!--\s*schema\s*=\s*([^\s>]+)\s*-->',
  );

  // ── Headline marker detection ──

  /// Regex for headline markers at line start inside body text.
  static final RegExp headlineMarkerPattern = RegExp(r'^#{1,6}\s', multiLine: true);
}

/// A match result from searching the markdown document.
class MdSearchResult {
  const MdSearchResult({
    required this.sectionHeadline,
    required this.matchText,
    required this.contextBefore,
    required this.contextAfter,
    required this.lineNumber,
    required this.offset,
    required this.length,
  });

  /// Headline of the containing section.
  final String sectionHeadline;

  /// The matched text.
  final String matchText;

  /// Text before the match (for context display).
  final String contextBefore;

  /// Text after the match (for context display).
  final String contextAfter;

  /// Line number in the source (0-based).
  final int lineNumber;

  /// Character offset in the raw markdown.
  final int offset;

  /// Length of the match.
  final int length;
}

/// Represents a section extracted from a markdown document.
///
/// Aligns with the `tom_doc_scanner` Section concept: a headline with its
/// body text and nested subsections.
class MdSection {
  MdSection({
    required this.headline,
    required this.level,
    this.id,
    this.commentMetadata = const {},
    this.text = '',
    List<MdSection>? subsections,
    this.sourceLineStart,
    this.sourceLineEnd,
  }) : subsections = subsections ?? [];

  /// Heading text without the `#` markers and ID markers.
  String headline;

  /// Heading level 1–6.
  int level;

  /// Optional section ID extracted from `[id]` or `<!--[id]-->`.
  String? id;

  /// Key-value metadata from HTML comments (e.g., `component-id=auth`).
  Map<String, String> commentMetadata;

  /// Body text between this heading and the next heading.
  String text;

  /// Child sections.
  final List<MdSection> subsections;

  /// Line number in the source where this section starts (0-based).
  int? sourceLineStart;

  /// Line number in the source where this section ends (0-based, exclusive).
  int? sourceLineEnd;

  /// Returns the raw markdown for this section (excluding subsections).
  String toHeadlineMarkdown() {
    final prefix = '#' * level;
    if (id == null && commentMetadata.isEmpty) {
      return '$prefix $headline';
    }
    final metaParts = commentMetadata.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    final idStr = id ?? '';
    final sep = idStr.isNotEmpty && metaParts.isNotEmpty ? ' ' : '';
    return '$prefix <!--[$idStr]$sep$metaParts --> $headline';
  }

  /// Returns full markdown including body and subsections recursively.
  String toMarkdown() {
    final buffer = StringBuffer(toHeadlineMarkdown());
    if (text.isNotEmpty) {
      buffer.write('\n\n');
      buffer.write(text);
    }
    for (final sub in subsections) {
      buffer.write('\n\n');
      buffer.write(sub.toMarkdown());
    }
    return buffer.toString();
  }

  /// Flat list of this section plus all descendants.
  List<MdSection> get allDescendants {
    final result = <MdSection>[this];
    for (final sub in subsections) {
      result.addAll(sub.allDescendants);
    }
    return result;
  }

  @override
  String toString() => 'MdSection(level=$level, headline=$headline)';
}

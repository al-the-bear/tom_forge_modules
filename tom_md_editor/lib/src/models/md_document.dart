import 'md_section.dart';

/// Represents a full markdown document as a tree of sections.
class MdDocument {
  MdDocument({
    required this.sections,
    this.title,
    this.schemaId,
    this.path,
    this.lastModified,
  });

  /// Top-level sections.
  final List<MdSection> sections;

  /// Document title (from first H1, if any).
  String? title;

  /// Schema identifier detected from `<!-- schema=... -->`.
  String? schemaId;

  /// Source file path (if applicable).
  String? path;

  /// Last modification timestamp (if applicable).
  DateTime? lastModified;

  /// Flat list of all sections in document order.
  List<MdSection> get allSections {
    final result = <MdSection>[];
    for (final s in sections) {
      result.addAll(s.allDescendants);
    }
    return result;
  }

  /// Find a section by its ID.
  MdSection? findById(String id) {
    for (final s in allSections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Maximum nesting depth.
  int get hierarchyDepth {
    int depth(MdSection s) {
      if (s.subsections.isEmpty) return 1;
      return 1 + s.subsections.map(depth).reduce((a, b) => a > b ? a : b);
    }
    if (sections.isEmpty) return 0;
    return sections.map(depth).reduce((a, b) => a > b ? a : b);
  }
}

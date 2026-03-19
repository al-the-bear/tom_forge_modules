import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;

import '../models/md_document.dart';
import '../models/md_section.dart';

/// Describes an allowed child section type from the schema.
class AllowedSubsection {
  final String typeName;
  final specs.SubsectionConstraint constraint;
  final specs.SectionTypeDef? typeDef;

  AllowedSubsection({
    required this.typeName,
    required this.constraint,
    this.typeDef,
  });

  /// Display name with dashes replaced by spaces.
  String get displayName => typeName.replaceAll('-', ' ');

  /// Capitalized display name for menus.
  String get capitalizedName => displayName
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// The ID prefix for this section type.
  String? get prefix => typeDef?.prefix;

  /// Human-readable description from the schema.
  String? get description => typeDef?.description;
}

/// Provides schema-aware section analysis utilities.
///
/// Given a [specs.DocSpecSchema], helps determine each section's type and
/// what child sections are allowed.
class SchemaSectionHelper {
  final specs.DocSpecSchema schema;

  SchemaSectionHelper(this.schema);

  /// Determine the section-type name for a section.
  ///
  /// Matching strategy:
  /// 1. If the section has an ID, match by longest prefix.
  /// 2. For top-level sections (direct children of document), match by
  ///    the document structure section names.
  String? getSectionTypeName(
    MdSection section, {
    MdDocument? document,
  }) {
    // Try prefix match first (most reliable when IDs exist).
    final byPrefix = _matchByPrefix(section);
    if (byPrefix != null) return byPrefix;

    // For top-level sections, match by document structure.
    if (document != null) {
      final byStructure = _matchTopLevel(section, document);
      if (byStructure != null) return byStructure;
    }

    return null;
  }

  /// Get the [SectionTypeDef] for a section.
  specs.SectionTypeDef? getSectionTypeDef(
    MdSection section, {
    MdDocument? document,
  }) {
    final name = getSectionTypeName(section, document: document);
    if (name == null) return null;
    return schema.sectionTypes[name];
  }

  /// Get allowed child section types for a given section.
  ///
  /// Returns an empty list if no schema constraints are defined or
  /// the section's type is unknown.
  List<AllowedSubsection> getAllowedSubsections(
    MdSection section, {
    MdDocument? document,
  }) {
    final typeName = getSectionTypeName(section, document: document);
    if (typeName == null) return [];

    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return [];

    if (typeDef.subsectionTypes == null ||
        typeDef.subsectionTypes!.isEmpty) {
      return [];
    }

    return typeDef.subsectionTypes!.entries.map((entry) {
      final childType = schema.sectionTypes[entry.key];
      return AllowedSubsection(
        typeName: entry.key,
        constraint: entry.value,
        typeDef: childType,
      );
    }).toList();
  }

  /// Get allowed top-level sections from the document structure.
  ///
  /// Returns the section names and types defined in `document.sections`.
  List<({String name, String sectionType, specs.SectionTypeDef? typeDef, bool optional})>
      getAllowedTopLevelSections() {
    return schema.document.sections.entries.map((entry) {
      final typeDef = schema.sectionTypes[entry.value.sectionType];
      return (
        name: entry.key,
        sectionType: entry.value.sectionType,
        typeDef: typeDef,
        optional: entry.value.optional ?? false,
      );
    }).toList();
  }

  /// Match a section to a type by its ID prefix.
  String? _matchByPrefix(MdSection section) {
    if (section.id == null || section.id!.isEmpty) return null;
    final sectionId = section.id!;

    String? bestMatch;
    var bestLen = 0;

    for (final entry in schema.sectionTypes.entries) {
      final prefix = entry.value.prefix;
      if (prefix != null &&
          sectionId.startsWith(prefix) &&
          prefix.length > bestLen) {
        bestMatch = entry.key;
        bestLen = prefix.length;
      }
    }
    return bestMatch;
  }

  /// Match a top-level section by headline against document structure names.
  String? _matchTopLevel(MdSection section, MdDocument document) {
    final isTopLevel = document.sections.contains(section);
    if (!isTopLevel) return null;

    final headline = section.headline.toLowerCase().trim();
    for (final entry in schema.document.sections.entries) {
      final sectionName = entry.key.toLowerCase().replaceAll('-', ' ');
      if (sectionName == headline ||
          entry.key.toLowerCase() == headline) {
        return entry.value.sectionType;
      }
    }
    return null;
  }
}

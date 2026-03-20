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

/// Describes a missing required section in the document.
class MissingSectionInfo {
  final String sectionName;
  final String sectionType;
  final specs.SectionTypeDef? typeDef;
  final bool isTopLevel;
  final MdSection? parentSection;

  const MissingSectionInfo({
    required this.sectionName,
    required this.sectionType,
    this.typeDef,
    this.isTopLevel = false,
    this.parentSection,
  });
}

/// Drop-target validity for position-aware drag-and-drop.
class DropTargetInfo {
  /// Whether the section can be dropped at this position.
  final bool isValid;

  /// Reason the drop is invalid, if applicable.
  final String? reason;

  const DropTargetInfo({required this.isValid, this.reason});
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

  // ── P1: Count-aware filtering ──

  /// Count how many sections of a given type exist in the document.
  int countSectionsOfType(String typeName, MdDocument document) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return 0;

    var count = 0;
    for (final section in document.allSections) {
      final name = getSectionTypeName(section, document: document);
      if (name == typeName) count++;
    }
    return count;
  }

  /// Whether a section type has reached its max-count-in-document limit.
  bool isTypeAtMaxCount(String typeName, MdDocument document) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return false;
    final max = typeDef.maxCountInDocument;
    if (max == null) return false;
    return countSectionsOfType(typeName, document) >= max;
  }

  /// Get allowed subsections filtered by max-count constraints.
  ///
  /// Unlike [getAllowedSubsections], this excludes types that have
  /// reached their max-count for the given parent.
  List<AllowedSubsection> getAvailableSubsections(
    MdSection section, {
    required MdDocument document,
  }) {
    final all = getAllowedSubsections(section, document: document);
    return all.where((sub) {
      // Check max-count within parent.
      if (sub.constraint.maxCount != null) {
        final existing = section.subsections.where((child) {
          final childType = getSectionTypeName(child, document: document);
          return childType == sub.typeName;
        }).length;
        if (existing >= sub.constraint.maxCount!) return false;
      }
      // Check max-count-in-document.
      if (!isTypeAtMaxCount(sub.typeName, document)) return true;
      return false;
    }).toList();
  }

  /// Get allowed top-level sections filtered by max-count constraints.
  List<({String name, String sectionType, specs.SectionTypeDef? typeDef, bool optional})>
      getAvailableTopLevelSections(MdDocument document) {
    return getAllowedTopLevelSections().where((entry) {
      return !isTypeAtMaxCount(entry.sectionType, document);
    }).toList();
  }

  // ── P1.3: Missing sections ──

  /// Get required sections missing from the document.
  List<MissingSectionInfo> getMissingSections(MdDocument document) {
    final missing = <MissingSectionInfo>[];

    // Check top-level required sections.
    for (final entry in schema.document.sections.entries) {
      if (entry.value.optional ?? false) continue;

      final exists = document.sections.any((s) {
        final typeName = getSectionTypeName(s, document: document);
        return typeName == entry.value.sectionType;
      });

      if (!exists) {
        missing.add(MissingSectionInfo(
          sectionName: entry.key,
          sectionType: entry.value.sectionType,
          typeDef: schema.sectionTypes[entry.value.sectionType],
          isTopLevel: true,
        ));
      }
    }

    // Check required subsections within existing sections.
    for (final section in document.allSections) {
      final typeName = getSectionTypeName(section, document: document);
      if (typeName == null) continue;
      final typeDef = schema.sectionTypes[typeName];
      if (typeDef?.subsectionTypes == null) continue;

      for (final subEntry in typeDef!.subsectionTypes!.entries) {
        final constraint = subEntry.value;
        final minCount =
            constraint.minCount ?? ((constraint.required ?? false) ? 1 : 0);
        if (minCount <= 0) continue;

        final existing = section.subsections.where((child) {
          final childType = getSectionTypeName(child, document: document);
          return childType == subEntry.key;
        }).length;

        if (existing < minCount) {
          for (var i = 0; i < minCount - existing; i++) {
            missing.add(MissingSectionInfo(
              sectionName: subEntry.key,
              sectionType: subEntry.key,
              typeDef: schema.sectionTypes[subEntry.key],
              parentSection: section,
            ));
          }
        }
      }
    }

    return missing;
  }

  // ── P6.1: For-each registry ──

  /// Get IDs from a for-each linked registry.
  ///
  /// Finds the registry section and extracts entry IDs by looking at
  /// the `link-to-field` key in each registry entry section.
  List<String> getRegistryIds(MdDocument document, String sectionName) {
    final sectionDef = schema.document.sections[sectionName];
    if (sectionDef?.forEach == null) return const [];

    final forEach = sectionDef!.forEach!;
    final registryType = forEach.sectionType;

    // Find sections of the registry type.
    final ids = <String>[];
    for (final section in document.allSections) {
      final typeName = getSectionTypeName(section, document: document);
      if (typeName == registryType) {
        // Extract the key field from the section text.
        final keyField = forEach.key;
        final value = _extractFieldValue(section.text, keyField);
        if (value != null) {
          ids.add(value);
        } else if (section.id != null) {
          ids.add(section.id!);
        }
      }
    }
    return ids;
  }

  // ── P6.2: Position-aware drag-drop ──

  /// Check if dropping a section at a given position would be valid.
  DropTargetInfo isValidDropTarget({
    required MdSection draggedSection,
    required MdSection? targetParent,
    required int targetIndex,
    required MdDocument document,
  }) {
    final draggedType = getSectionTypeName(
      draggedSection,
      document: document,
    );
    if (draggedType == null) {
      return const DropTargetInfo(isValid: true);
    }

    // Check if the parent accepts this type.
    if (targetParent != null) {
      final parentType = getSectionTypeName(
        targetParent,
        document: document,
      );
      if (parentType != null) {
        final parentDef = schema.sectionTypes[parentType];
        if (parentDef?.subsectionTypes != null &&
            !parentDef!.subsectionTypes!.containsKey(draggedType)) {
          return DropTargetInfo(
            isValid: false,
            reason: '$draggedType not allowed under $parentType',
          );
        }
      }
    }

    // Check position constraints from subsection declarations.
    final positionConstraint = _getPositionConstraint(draggedType, targetParent, document);
    if (positionConstraint != null) {
      final siblings = targetParent?.subsections ?? document.sections;
      if (positionConstraint == 'first' && targetIndex != 0) {
        return const DropTargetInfo(
          isValid: false,
          reason: 'Must be first child',
        );
      }
      if (positionConstraint == 'last' && targetIndex < siblings.length - 1) {
        return const DropTargetInfo(
          isValid: false,
          reason: 'Must be last child',
        );
      }
    }

    return const DropTargetInfo(isValid: true);
  }

  /// Get the position constraint for a type within a parent context.
  String? _getPositionConstraint(
    String typeName,
    MdSection? parent,
    MdDocument document,
  ) {
    if (parent == null) return null;

    // Check subsection declarations.
    final parentType = getSectionTypeName(parent, document: document);
    if (parentType == null) return null;

    // Look up in document-level subsection declarations.
    for (final entry in schema.document.sections.entries) {
      if (entry.value.sectionType == parentType) {
        final decls = schema.subsectionDeclarations?[entry.key];
        if (decls != null) {
          for (final declEntry in decls.entries) {
            if (declEntry.value.sectionType == typeName) {
              return declEntry.value.position;
            }
          }
        }
      }
    }
    return null;
  }

  /// Extract a field value from section text (e.g., "field-name: value").
  static String? _extractFieldValue(String text, String fieldName) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trimLeft();
      // Handle HTML comment fields: <!-- field-name: value -->
      final commentRegex = RegExp(
        r'<!--\s*' + RegExp.escape(fieldName) + r'\s*:\s*(.+?)\s*-->',
      );
      final commentMatch = commentRegex.firstMatch(trimmed);
      if (commentMatch != null) {
        return commentMatch.group(1)?.trim();
      }
      // Handle plain "- field-name: value" or "field-name: value".
      final content =
          trimmed.startsWith('- ') ? trimmed.substring(2) : trimmed;
      final colonIdx = content.indexOf(':');
      if (colonIdx > 0) {
        final key = content.substring(0, colonIdx).trim();
        if (key.toLowerCase() == fieldName.toLowerCase()) {
          return content.substring(colonIdx + 1).trim();
        }
      }
    }
    return null;
  }
}

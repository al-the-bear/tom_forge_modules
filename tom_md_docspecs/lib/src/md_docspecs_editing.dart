import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_md_editor/tom_md_editor.dart';

import 'md_docspecs_support.dart';
import 'validation/schema_section_helper.dart';
import 'validation/schema_template_helper.dart';

/// A DocSpecs schema on an [MdEditorController]: attaching it, reading it
/// back, and the edits the schema drives — scaffolding the sections it
/// requires and keeping for-each sections in step with their registry.
///
/// [setSchema] attaches the schema as the controller's schema support
/// ([MdDocSpecsSupport]); every edit here is one history entry through
/// [MdEditorController.editStructure].
extension MdDocSpecsEditing on MdEditorController {
  /// Set a schema for document validation.
  ///
  /// Once set, validation runs automatically on every content change
  /// and fires [MdEditorEventHandlers.onValidationChanged].
  void setSchema(specs.DocSpecSchema schema) =>
      setSchemaSupport(MdDocSpecsSupport(schema));

  /// The DocSpecs schema attached with [setSchema], if any.
  specs.DocSpecSchema? get schema => switch (schemaSupport) {
    final MdDocSpecsSupport support => support.schema,
    _ => null,
  };

  /// A [SchemaSectionHelper] for the current schema; null without one.
  SchemaSectionHelper? get schemaHelper {
    final s = schema;
    return s != null ? SchemaSectionHelper(s) : null;
  }

  /// A [SchemaTemplateHelper] for the current schema; null without one.
  SchemaTemplateHelper? get templateHelper {
    final s = schema;
    return s != null ? SchemaTemplateHelper(s) : null;
  }

  // ── P1.3: Auto-scaffold ──

  /// Scaffold all missing required sections into the document.
  ///
  /// Uses the schema's document structure to identify required sections
  /// that are missing, then inserts them with template content.
  /// Returns the number of sections created.
  Future<int> scaffoldMissingSections() async {
    final helper = schemaHelper;
    final tmpl = templateHelper;
    if (helper == null || tmpl == null) return 0;

    final missing = helper.getMissingSections(document);
    if (missing.isEmpty) return 0;

    final count = missing
        .where((m) => m.isTopLevel || m.parentSection != null)
        .length;
    var created = 0;
    editStructure('Scaffold $count missing sections', (document) {
      // Insert top-level missing sections first.
      for (final info in missing.where((m) => m.isTopLevel)) {
        document.sections.add(
          MdSection(
            headline: mdFormatSectionName(info.sectionName),
            level: 1,
            id: tmpl.generateSuggestedId(info.sectionType),
            text: tmpl.generateTemplate(info.sectionType),
          ),
        );
        created++;
      }

      // Insert subsection missing sections.
      for (final info in missing.where((m) => !m.isTopLevel)) {
        final parent = info.parentSection;
        if (parent == null) continue;
        parent.subsections.add(
          MdSection(
            headline: mdFormatSectionName(info.sectionName),
            level: parent.level + 1,
            id: tmpl.generateSuggestedId(info.sectionType),
            text: tmpl.generateTemplate(info.sectionType),
          ),
        );
        created++;
      }
      return created > 0;
    });
    return created;
  }

  /// Insert a single missing section matching [typeName].
  ///
  /// Finds the first missing section whose type matches [typeName] and
  /// scaffolds it into the document. Returns `true` if a section was created.
  Future<bool> scaffoldSectionByType(String typeName) async {
    final helper = schemaHelper;
    final tmpl = templateHelper;
    if (helper == null || tmpl == null) return false;

    final missing = helper.getMissingSections(document);
    final match = missing.where((m) => m.sectionType == typeName);
    if (match.isEmpty) return false;

    final info = match.first;
    final parent = info.parentSection;
    if (!info.isTopLevel && parent == null) return false;
    return editStructure('Insert $typeName section', (document) {
      final section = MdSection(
        headline: mdFormatSectionName(info.sectionName),
        level: info.isTopLevel ? 1 : (parent!.level + 1),
        id: tmpl.generateSuggestedId(info.sectionType),
        text: tmpl.generateTemplate(info.sectionType),
      );
      if (info.isTopLevel) {
        document.sections.add(section);
      } else {
        parent!.subsections.add(section);
      }
      return true;
    });
  }

  // ── For-each sync ──

  /// Compute the sync state for all for-each linked sections.
  ///
  /// Returns a [ForEachSyncResult] describing which sections need to be
  /// created (missing from registry) and which are orphaned (registry entry
  /// removed). Does NOT modify the document — callers decide what to apply.
  ForEachSyncResult computeForEachSync() {
    final helper = schemaHelper;
    final tmpl = templateHelper;
    if (helper == null || tmpl == null) {
      return const ForEachSyncResult(missing: [], orphaned: []);
    }

    final missing = <ForEachMissing>[];
    final orphaned = <ForEachOrphaned>[];

    for (final entry in (schema?.document.sections ?? {}).entries) {
      final sectionDef = entry.value;
      if (sectionDef.forEach == null) continue;

      final sectionName = entry.key;
      final forEach = sectionDef.forEach!;
      final registryIds = helper.getRegistryIds(document, sectionName);

      // Find the parent section for this for-each group.
      final parentSections = document.sections.where((s) {
        final typeName = helper.getSectionTypeName(s, document: document);
        return typeName == sectionDef.sectionType;
      });
      if (parentSections.isEmpty) continue;
      final parent = parentSections.first;

      // Get existing child IDs.
      final existingIds = <String>{};
      for (final child in parent.subsections) {
        if (child.id != null) existingIds.add(child.id!);
      }

      // Missing: registry IDs not in existing children.
      for (final id in registryIds) {
        if (!existingIds.contains(id)) {
          missing.add(
            ForEachMissing(
              sectionName: sectionName,
              registryId: id,
              parentSection: parent,
              sectionType: forEach.sectionType,
            ),
          );
        }
      }

      // Orphaned: existing children not in registry.
      final registryIdSet = registryIds.toSet();
      for (final child in parent.subsections) {
        if (child.id != null && !registryIdSet.contains(child.id!)) {
          orphaned.add(
            ForEachOrphaned(
              sectionName: sectionName,
              sectionId: child.id!,
              section: child,
              parentSection: parent,
            ),
          );
        }
      }
    }

    return ForEachSyncResult(missing: missing, orphaned: orphaned);
  }

  /// Create sections for missing for-each entries.
  ///
  /// Returns the number of sections created.
  Future<int> syncForEachMissing(List<ForEachMissing> entries) async {
    final tmpl = templateHelper;
    if (tmpl == null || entries.isEmpty) return 0;

    var created = 0;
    editStructure('Sync: create ${entries.length} for-each sections', (_) {
      for (final entry in entries) {
        entry.parentSection.subsections.add(
          MdSection(
            headline: mdFormatSectionName(entry.registryId),
            level: entry.parentSection.level + 1,
            id: entry.registryId,
            text: tmpl.generateTemplate(entry.sectionType),
          ),
        );
        created++;
      }
      return created > 0;
    });
    return created;
  }

  /// Remove orphaned for-each sections.
  ///
  /// Returns the number of sections removed.
  Future<int> removeForEachOrphaned(List<ForEachOrphaned> entries) async {
    if (entries.isEmpty) return 0;

    var removed = 0;
    editStructure('Sync: remove ${entries.length} orphaned sections', (_) {
      for (final entry in entries) {
        entry.parentSection.subsections.remove(entry.section);
        removed++;
      }
      return removed > 0;
    });
    return removed;
  }
}

/// A schema section name as a headline: `open-questions` → `Open Questions`.
String mdFormatSectionName(String name) {
  return name
      .split('-')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ── For-each sync data classes ──

/// Result of a for-each sync analysis.
class ForEachSyncResult {
  /// Entries that exist in the registry but have no corresponding section.
  final List<ForEachMissing> missing;

  /// Sections that exist but have no corresponding registry entry.
  final List<ForEachOrphaned> orphaned;

  const ForEachSyncResult({required this.missing, required this.orphaned});

  /// Whether everything is in sync.
  bool get isSynced => missing.isEmpty && orphaned.isEmpty;
}

/// A registry entry with no corresponding detail section.
class ForEachMissing {
  final String sectionName;
  final String registryId;
  final MdSection parentSection;
  final String sectionType;

  const ForEachMissing({
    required this.sectionName,
    required this.registryId,
    required this.parentSection,
    required this.sectionType,
  });
}

/// A detail section with no corresponding registry entry.
class ForEachOrphaned {
  final String sectionName;
  final String sectionId;
  final MdSection section;
  final MdSection parentSection;

  const ForEachOrphaned({
    required this.sectionName,
    required this.sectionId,
    required this.section,
    required this.parentSection,
  });
}

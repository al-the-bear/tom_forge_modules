import 'package:flutter/widgets.dart';
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

import 'md_docspecs_editing.dart';
import 'validation/md_schema_validator.dart';
import 'validation/schema_section_helper.dart';
import 'validation/schema_template_helper.dart';
import 'widgets/md_char_counter.dart';
import 'widgets/md_for_each_sync_banner.dart';
import 'widgets/md_form_editor.dart';
import 'widgets/md_quick_fix_menu.dart';
import 'widgets/md_schema_info_panel.dart';
import 'widgets/md_validation_prompt_banner.dart';

/// A DocSpecs schema as the Markdown editor's schema support
/// ([MdSchemaSupport]): validation through `tom_doc_scanner`, the section
/// types, templates, ids and tags of `tom_doc_specs`, and the schema's panels
/// — the for-each sync banner above the outline, the info panel below it,
/// validation prompts above the rendered view, the character counter in the
/// raw editor, forms for form-type sections.
///
/// Attach it with `controller.setSchema(schema)` ([MdDocSpecsEditing]), or
/// `controller.setSchemaSupport(MdDocSpecsSupport(schema))`.
class MdDocSpecsSupport implements MdSchemaSupport {
  MdDocSpecsSupport(this.schema)
    : _sections = SchemaSectionHelper(schema),
      _templates = SchemaTemplateHelper(schema),
      _validator = MdSchemaValidator()..setSchema(schema);

  /// The schema.
  final specs.DocSpecSchema schema;

  final SchemaSectionHelper _sections;
  final SchemaTemplateHelper _templates;
  final MdSchemaValidator _validator;

  @override
  String get schemaId => schema.fullId;

  @override
  List<ValidationError> validate(MdDocument document) =>
      _validator.validate(document);

  // ── Section types ──

  @override
  String? sectionTypeName(MdSection section, MdDocument document) =>
      _sections.getSectionTypeName(section, document: document);

  @override
  String? sectionTypeTooltip(String typeName) {
    final typeDef = schema.sectionTypes[typeName];
    final parts = <String>[typeName];
    if (typeDef?.description != null) parts.add(typeDef!.description!);
    if (typeDef?.format != null) parts.add('Format: ${typeDef!.format}');
    return parts.join(' — ');
  }

  MdSchemaSectionType _subsection(AllowedSubsection sub) {
    final info = _templates.getIdPatternInfo(sub.typeName);
    return MdSchemaSectionType(
      typeName: sub.typeName,
      prefix: sub.prefix,
      description: sub.description,
      idPattern: info?.pattern,
      idPatternErrorMessage: info?.errorMessage,
    );
  }

  MdSchemaSectionType _topLevel(
    ({
      String name,
      String sectionType,
      specs.SectionTypeDef? typeDef,
      bool optional,
    })
    entry,
  ) {
    final info = _templates.getIdPatternInfo(entry.sectionType);
    return MdSchemaSectionType(
      typeName: entry.sectionType,
      name: entry.name,
      prefix: entry.typeDef?.prefix,
      description: entry.typeDef?.description,
      optional: entry.optional,
      idPattern: info?.pattern,
      idPatternErrorMessage: info?.errorMessage,
    );
  }

  @override
  List<MdSchemaSectionType> allowedSubsections(
    MdSection parent,
    MdDocument document,
  ) => _sections
      .getAllowedSubsections(parent, document: document)
      .map(_subsection)
      .toList();

  @override
  List<MdSchemaSectionType> availableSubsections(
    MdSection parent,
    MdDocument document,
  ) => _sections
      .getAvailableSubsections(parent, document: document)
      .map(_subsection)
      .toList();

  @override
  String countLabel(String typeName, MdDocument document) {
    final typeDef = schema.sectionTypes[typeName];
    if (typeDef?.maxCountInDocument == null) return '';
    final count = _sections.countSectionsOfType(typeName, document);
    return '($count/${typeDef!.maxCountInDocument})';
  }

  @override
  List<MdSchemaSectionType> allowedTopLevelSections() =>
      _sections.getAllowedTopLevelSections().map(_topLevel).toList();

  @override
  List<MdSchemaSectionType> availableTopLevelSections(MdDocument document) =>
      _sections.getAvailableTopLevelSections(document).map(_topLevel).toList();

  @override
  bool isValidDrop({
    required MdSection draggedSection,
    required MdSection? targetParent,
    required int targetIndex,
    required MdDocument document,
  }) => _sections
      .isValidDropTarget(
        draggedSection: draggedSection,
        targetParent: targetParent,
        targetIndex: targetIndex,
        document: document,
      )
      .isValid;

  // ── Ids, templates, tags, fields ──

  @override
  List<String> idPrefixes() => [
    for (final typeDef in schema.sectionTypes.values)
      if (typeDef.prefix case final prefix? when prefix.isNotEmpty) prefix,
  ];

  @override
  String? suggestedId(String typeName) =>
      _templates.generateSuggestedId(typeName);

  @override
  String? idPattern(String typeName) => _templates.getIdPattern(typeName);

  @override
  List<String> registryIds(MdDocument document, String typeName) =>
      _sections.getRegistryIds(document, typeName);

  @override
  String template(String typeName) => _templates.generateTemplate(typeName);

  @override
  List<String> allowedTags(String typeName) =>
      _templates.getAllowedTags(typeName);

  @override
  List<String> requiredFields(String typeName) =>
      _templates.getRequiredFields(typeName);

  @override
  List<String> codeLanguages(String typeName) =>
      _templates.getCodeLanguages(typeName);

  // ── Quick fixes ──

  @override
  List<MdSchemaAction> quickFixes(
    MdEditorController controller,
    MdSection section,
    List<ValidationError> errors, {
    required void Function(MdSection section) onRename,
  }) {
    VoidCallback onSection(
      String sectionId,
      void Function(MdSection target) action,
    ) => () {
      final target = controller.findSectionById(sectionId);
      if (target != null) action(target);
    };

    return [
      for (final error in errors)
        for (final fix in QuickFixAnalyzer.getFixesForError(
          error,
          onInsertSection: (typeName) => () {
            controller.scaffoldSectionByType(typeName);
          },
          onNavigateToSection: (sectionId) =>
              onSection(sectionId, controller.selectSection),
          onRenameId: (sectionId) => onSection(sectionId, onRename),
          onDeleteSection: (sectionId) =>
              onSection(sectionId, controller.deleteSection),
          onMoveSection: (sectionId) =>
              onSection(sectionId, controller.moveSectionUp),
        ))
          MdSchemaAction(
            label: fix.label,
            icon: fix.icon,
            onExecute: fix.onExecute,
          ),
    ];
  }

  // ── Panels ──

  @override
  Widget? buildOutlineHeader(
    BuildContext context,
    MdEditorController controller,
    MdEditorTheme theme,
  ) => MdForEachSyncBanner(controller: controller, theme: theme);

  @override
  Widget? buildOutlineFooter(
    BuildContext context,
    MdEditorController controller,
    MdEditorTheme theme,
    MdEditorSettings settings,
  ) => settings.showSchemaInfoPanel
      ? MdSchemaInfoPanel(schema: schema, theme: theme)
      : null;

  @override
  List<Widget> buildPreviewContext(
    BuildContext context,
    MdEditorController controller,
    MdSection section,
    String typeName,
    MdEditorTheme theme,
    MdEditorSettings settings,
  ) {
    if (schema.sectionTypes[typeName] == null) return const [];
    // Validation prompt banner (P6.3).
    if (!settings.showValidationPrompts) return const [];

    // Find parent section ID for ${parent.id} interpolation.
    String? parentId;
    for (final topLevel in controller.document.sections) {
      if (topLevel == section) break;
      for (final child in topLevel.subsections) {
        if (child == section) {
          parentId = topLevel.id;
          break;
        }
      }
      if (parentId != null) break;
    }

    final prompt = _templates.getDocumentValidationPrompt(
      typeName: typeName,
      sectionId: section.id,
      parentSectionId: parentId,
    );
    if (prompt == null) return const [];
    return [
      MdValidationPromptBanner(
        prompt: prompt,
        sectionId: section.id,
        sectionText: section.text,
        sectionLineNumber: section.sourceLineStart,
        sectionTags: section.commentMetadata['tags'],
        sectionFields: section.commentMetadata.isEmpty
            ? null
            : section.commentMetadata,
        parentId: parentId,
        theme: theme,
      ),
    ];
  }

  @override
  Widget? buildRawEditorStatus(
    BuildContext context,
    MdEditorController controller,
    MdSection section,
    MdEditorTheme theme,
    MdEditorSettings settings,
  ) {
    if (!settings.showCharCounter) return null;
    final typeName = sectionTypeName(section, controller.document);
    if (typeName == null) return null;

    final constraints = _templates.getTextConstraints(typeName);
    if (constraints.min == null &&
        constraints.max == null &&
        !constraints.required) {
      return null;
    }

    return MdCharCounter(
      currentLength: section.text.length,
      minLength: constraints.min,
      maxLength: constraints.max,
      textRequired: constraints.required,
      theme: theme,
    );
  }

  @override
  bool hasSectionForm(String typeName) =>
      _templates.getFormType(typeName) != null;

  @override
  Widget? buildSectionForm(
    MdEditorController controller,
    MdSection section,
    String typeName,
    MdEditorTheme theme,
  ) {
    final formType = _templates.getFormType(typeName);
    if (formType == null) return null;
    final currentValues = MdFormEditor.parseFormContent(section.text);
    // Detect whether original text uses list-prefix format (e.g., "- Field: value").
    final useListPrefix = section.text.trimLeft().startsWith('- ');
    return MdFormEditor(
      formType: formType,
      currentValues: currentValues,
      customTags: schema.customTags,
      requiredFields: _templates.getRequiredFields(typeName),
      textPatternCheck: schema.sectionTypes[typeName]?.patternCheckText,
      theme: theme,
      useListPrefix: useListPrefix,
      onChanged: (values) {
        final newText = MdFormEditor.serializeFormContent(
          values,
          formType,
          useListPrefix: useListPrefix,
        );
        controller.updateSectionText(section, newText);
      },
    );
  }
}

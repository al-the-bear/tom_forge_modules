import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../controller/md_editor_controller.dart';
import '../models/md_document.dart';
import '../models/md_section.dart';
import '../settings/md_editor_settings.dart';
import '../theme/md_editor_theme.dart';

/// A section type a document schema offers at a place in the document: as a
/// subsection of a section, or as a top-level section.
@immutable
class MdSchemaSectionType {
  const MdSchemaSectionType({
    required this.typeName,
    this.name,
    this.prefix,
    this.description,
    this.optional = true,
    this.idPattern,
    this.idPatternErrorMessage,
  });

  /// The schema's section type.
  final String typeName;

  /// The section's name in the document structure (a top-level entry), when
  /// it has one besides its type.
  final String? name;

  /// The id prefix of the type.
  final String? prefix;

  /// What the type is for, from the schema.
  final String? description;

  /// Whether the document may leave the section out.
  final bool optional;

  /// The pattern a section id of this type must match.
  final String? idPattern;

  /// The message shown when an id does not match [idPattern].
  final String? idPatternErrorMessage;

  /// The name, else the type, with dashes as spaces.
  String get displayName => (name ?? typeName).replaceAll('-', ' ');

  /// [displayName] with each word capitalised, for menus.
  String get capitalizedName => displayName
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// An action a schema offers on a section, e.g. a quick fix for one of its
/// validation errors.
@immutable
class MdSchemaAction {
  const MdSchemaAction({
    required this.label,
    required this.icon,
    required this.onExecute,
  });

  final String label;
  final IconData icon;
  final VoidCallback onExecute;
}

/// The extension point through which a document schema takes part in the
/// editor: validation, section types, templates, ids, tags, the forms and
/// panels of a schema-typed document.
///
/// The editor core knows no schema language. A schema plugin implements this
/// interface (`tom_md_docspecs` for DocSpecs) and is attached to a controller
/// with [MdEditorController.setSchemaSupport]; without one the editor shows
/// the document as plain Markdown and every schema feature is absent.
///
/// The `build…` methods contribute widgets to the editor's panels; each
/// answers null (or an empty list) when it has nothing to show.
abstract class MdSchemaSupport {
  /// The schema's id with its version, e.g. `quest-overview/1.0`.
  String get schemaId;

  /// The validation errors of [document].
  List<ValidationError> validate(MdDocument document);

  // ── Section types ──

  /// The schema type of [section], or null when it has none.
  String? sectionTypeName(MdSection section, MdDocument document);

  /// One line describing [typeName] for a tooltip: its name, description and
  /// format.
  String? sectionTypeTooltip(String typeName);

  /// Every subsection type [parent] may hold.
  List<MdSchemaSectionType> allowedSubsections(
    MdSection parent,
    MdDocument document,
  );

  /// The subsection types [parent] may still take (a type at its maximum
  /// count left out).
  List<MdSchemaSectionType> availableSubsections(
    MdSection parent,
    MdDocument document,
  );

  /// How many sections of [typeName] the document has of its maximum, e.g.
  /// `(2/5)`; empty when the type has no maximum.
  String countLabel(String typeName, MdDocument document);

  /// Every top-level section the document structure declares.
  List<MdSchemaSectionType> allowedTopLevelSections();

  /// The top-level sections the document may still take.
  List<MdSchemaSectionType> availableTopLevelSections(MdDocument document);

  /// Whether [draggedSection] may be dropped under [targetParent] (null: the
  /// top level) at [targetIndex].
  bool isValidDrop({
    required MdSection draggedSection,
    required MdSection? targetParent,
    required int targetIndex,
    required MdDocument document,
  });

  // ── Ids, templates, tags, fields ──

  /// The id prefixes of every section type, suggested for a new section.
  List<String> idPrefixes();

  /// The id suggested for a new section of [typeName].
  String? suggestedId(String typeName);

  /// The pattern a section id of [typeName] must match.
  String? idPattern(String typeName);

  /// The ids the document's registry lists for sections of [typeName].
  List<String> registryIds(MdDocument document, String typeName);

  /// The text a new section of [typeName] starts with.
  String template(String typeName);

  /// The tags a section of [typeName] may carry.
  List<String> allowedTags(String typeName);

  /// The metadata fields a section of [typeName] must have.
  List<String> requiredFields(String typeName);

  /// The code languages a section of [typeName] may hold.
  List<String> codeLanguages(String typeName);

  // ── Quick fixes ──

  /// The fixes for [errors] of [section]. [onRename] opens the editor's
  /// dialog that renames a section.
  List<MdSchemaAction> quickFixes(
    MdEditorController controller,
    MdSection section,
    List<ValidationError> errors, {
    required void Function(MdSection section) onRename,
  });

  // ── Panels ──

  /// Shown above the outline (e.g. sections to create or remove).
  Widget? buildOutlineHeader(
    BuildContext context,
    MdEditorController controller,
    MdEditorTheme theme,
  );

  /// Shown below the outline (e.g. what the schema is).
  Widget? buildOutlineFooter(
    BuildContext context,
    MdEditorController controller,
    MdEditorTheme theme,
    MdEditorSettings settings,
  );

  /// Shown above the rendered view while [section] of [typeName] is
  /// selected (e.g. what a reviewer should check).
  List<Widget> buildPreviewContext(
    BuildContext context,
    MdEditorController controller,
    MdSection section,
    String typeName,
    MdEditorTheme theme,
    MdEditorSettings settings,
  );

  /// Shown in the raw editor's title bar for the selected [section] (e.g. a
  /// character counter).
  Widget? buildRawEditorStatus(
    BuildContext context,
    MdEditorController controller,
    MdSection section,
    MdEditorTheme theme,
    MdEditorSettings settings,
  );

  /// Whether a section of [typeName] is edited as a form in the rendered
  /// view, in place of its text.
  bool hasSectionForm(String typeName);

  /// The form [section] of [typeName] is edited with; it writes its values
  /// back through [controller].
  Widget? buildSectionForm(
    MdEditorController controller,
    MdSection section,
    String typeName,
    MdEditorTheme theme,
  );
}

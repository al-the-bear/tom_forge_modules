import 'content_field.dart';

/// The level of a content record in the catalog tree (§6a):
/// component → module → optional submodule.
enum ContentRecordKind { component, module, submodule }

/// One node of the content catalog tree (§6a) — a component, one of its
/// modules, or a module's optional submodule.
///
/// Records are built from a component file's YAML by [parseComponentRecord];
/// the nested `modules:` / `submodules:` lists become [children]. Each record
/// carries its classified [fields] (managed vs editable) for the editor pane.
class ContentRecord {
  const ContentRecord({
    required this.kind,
    required this.id,
    required this.fields,
    required this.children,
    this.name,
    this.provenance,
  });

  /// component / module / submodule.
  final ContentRecordKind kind;

  /// The record's `id` (falls back to a synthetic index id when absent).
  final String id;

  /// Optional `name` for display; falls back to [id] in the UI.
  final String? name;

  /// Human-readable provenance from the record's `_generated` block (§6a), e.g.
  /// `by: tom-generate · at: 2026-06-01T10:00:00Z`. `null` when the record has
  /// no `_generated` block. Surfaced on managed fields so it is always clear
  /// what produced a generated value.
  final String? provenance;

  /// Classified fields, in document order.
  final List<ContentField> fields;

  /// Nested records (a component's modules, a module's submodules).
  final List<ContentRecord> children;

  /// Display label: the name when present, else the id.
  String get label => name ?? id;

  /// The editable fields, in document order.
  Iterable<ContentField> get editableFields =>
      fields.where((f) => f.isEditable);

  /// The generator-managed (read-only) fields, in document order.
  Iterable<ContentField> get managedFields =>
      fields.where((f) => !f.isEditable);
}

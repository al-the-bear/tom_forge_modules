import 'content_field.dart';
import 'content_group.dart';

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
    this.source,
    this.groups = const [],
  });

  /// component / module / submodule.
  final ContentRecordKind kind;

  /// The record's `id` (falls back to a synthetic index id when absent).
  final String id;

  /// Optional `name` for display; falls back to [id] in the UI.
  final String? name;

  /// The record's in-repo source path relative to the website's `sourceRoot`,
  /// used to resolve repo-sourced docs (§9 item 5). For a component this is its
  /// `_generated.source` (the repo root); for a module/submodule it is its
  /// `path` field. `null` when the record carries neither.
  final String? source;

  /// Human-readable provenance from the record's `_generated` block (§6a), e.g.
  /// `by: tom-generate · at: 2026-06-01T10:00:00Z`. `null` when the record has
  /// no `_generated` block. Surfaced on managed fields so it is always clear
  /// what produced a generated value.
  final String? provenance;

  /// Classified fields, in document order.
  final List<ContentField> fields;

  /// Nested records (a component's modules, a module's submodules).
  final List<ContentRecord> children;

  /// The component's hand-authored module groups (§9 item 1), in author order.
  ///
  /// Editable and never generator-owned: the generator manages only
  /// `[id, name, category, modules]`, so this block round-trips across
  /// regeneration. Empty for modules and submodules (only components carry
  /// groups) and for components without a `groups:` block. See [ContentGroup].
  final List<ContentGroup> groups;

  /// The ids of this record's direct module children, for validating that a
  /// group's members ([ContentGroup.members]) each resolve to a real module.
  Set<String> get moduleIds =>
      {for (final child in children) child.id};

  /// The module ids that appear in a [groups] member list but are **not** real
  /// modules of this component (§9 item 1 validation). Empty when every member
  /// resolves; non-empty flags a stale hand edit the browser should surface.
  Set<String> get unknownGroupMembers {
    final ids = moduleIds;
    return {
      for (final group in groups)
        for (final member in group.members)
          if (!ids.contains(member)) member,
    };
  }

  /// The module ids not assigned to any [groups] entry — the "Other modules"
  /// bucket shown on the component page (§9 item 1). Order follows [children].
  List<String> get ungroupedModuleIds {
    final grouped = {
      for (final group in groups) ...group.members,
    };
    return [
      for (final child in children)
        if (!grouped.contains(child.id)) child.id,
    ];
  }

  /// Display label: the name when present, else the id.
  String get label => name ?? id;

  /// The editable fields, in document order.
  Iterable<ContentField> get editableFields =>
      fields.where((f) => f.isEditable);

  /// The generator-managed (read-only) fields, in document order.
  Iterable<ContentField> get managedFields =>
      fields.where((f) => !f.isEditable);
}

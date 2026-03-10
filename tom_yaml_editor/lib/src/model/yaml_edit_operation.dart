import 'yaml_document_model.dart';

/// Describes an edit operation on a YAML document.
///
/// Each operation captures the before and after state to support undo/redo.
class YamlEditOperation {
  /// The kind of edit.
  final YamlEditKind kind;

  /// The path in the document where the edit occurred.
  final List<String> path;

  /// Document state before the edit.
  final YamlDocumentModel oldDocument;

  /// Document state after the edit.
  final YamlDocumentModel newDocument;

  /// For [YamlEditKind.moveListItem]: the original index of the moved item.
  final int? moveOldIndex;

  /// For [YamlEditKind.moveListItem]: the new index of the moved item.
  final int? moveNewIndex;

  const YamlEditOperation({
    required this.kind,
    required this.path,
    required this.oldDocument,
    required this.newDocument,
    this.moveOldIndex,
    this.moveNewIndex,
  });

  /// Apply this operation (transition to newDocument).
  YamlDocumentModel apply(YamlDocumentModel current) => newDocument;

  /// Revert this operation (transition back to oldDocument).
  YamlDocumentModel revert(YamlDocumentModel current) => oldDocument;
}

/// Kinds of YAML edit operations.
enum YamlEditKind {
  /// Replace the entire document.
  replaceDocument,

  /// Set a scalar value at a path.
  setValue,

  /// Insert a new key at a path.
  insertKey,

  /// Remove a key at a path.
  removeKey,

  /// Reorder keys within a map.
  reorderKeys,

  /// Insert a list item.
  insertListItem,

  /// Remove a list item.
  removeListItem,

  /// Move a list item from one index to another.
  moveListItem,
}

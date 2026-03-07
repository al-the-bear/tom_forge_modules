import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import 'model/yaml_document_model.dart';
import 'model/yaml_edit_operation.dart';
import 'schema/yaml_schema.dart';

/// Controller for the YAML schema editor.
///
/// Manages the YAML document state, undo/redo history, validation,
/// and notifies listeners of changes.
///
/// Uses [UndoHistory] from `tom_editors_shared` for undo/redo management
/// and [ValidationError] for structured error reporting.
///
/// ```dart
/// final controller = YamlEditorController(
///   initialYaml: 'name: hello\nversion: 1',
///   schema: mySchema,
/// );
///
/// // Listen for changes
/// controller.addListener(() {
///   print('YAML changed: ${controller.yamlText}');
/// });
///
/// // Get current state
/// print(controller.isValid); // true/false
/// print(controller.errors);  // validation errors
/// ```
class YamlEditorController extends ChangeNotifier {
  /// The current YAML document model (non-destructive representation).
  YamlDocumentModel _document;

  /// The JSON Schema used for validation and construction help.
  final YamlSchema? _schema;

  /// Typed undo/redo history backed by the shared UndoHistory component.
  late final UndoHistory<YamlEditOperation> _history;

  /// Cached validation errors, recomputed on every document change.
  List<ValidationError> _cachedErrors = [];

  /// Propagated error map for tree decoration.
  Map<String, List<ValidationError>> _propagatedErrors = {};

  /// Creates a controller with optional initial YAML and schema.
  YamlEditorController({
    String initialYaml = '',
    YamlSchema? schema,
    int maxUndoHistory = 100,
  })  : _document = YamlDocumentModel.parse(initialYaml),
        _schema = schema {
    _history = UndoHistory<YamlEditOperation>(maxDepth: maxUndoHistory);
    _revalidate();
  }

  /// The current YAML text (serialized from the non-destructive model).
  String get yamlText => _document.toYamlString();

  /// The current document model.
  YamlDocumentModel get document => _document;

  /// The schema, if any.
  YamlSchema? get schema => _schema;

  /// Whether the document is valid according to the schema.
  bool get isValid => _cachedErrors.isEmpty;

  /// Current validation errors (structured [ValidationError] objects).
  List<ValidationError> get errors => List.unmodifiable(_cachedErrors);

  /// Propagated error map — keyed by path hash, includes ancestor rollups.
  Map<String, List<ValidationError>> get propagatedErrors =>
      Map.unmodifiable(_propagatedErrors);

  /// Get validation errors directly at a specific path (not propagated).
  List<ValidationError> validationErrorsAt(List<Object> path) {
    return ErrorPropagator.directErrorsAt(_cachedErrors, path);
  }

  /// Get error/warning counts at or below a path (including propagated).
  ({int errors, int warnings}) errorCountsAt(List<Object> path) {
    return ErrorPropagator.countAt(_propagatedErrors, path);
  }

  /// Whether undo is available.
  bool get canUndo => _history.canUndo;

  /// Whether redo is available.
  bool get canRedo => _history.canRedo;

  /// Apply an edit operation to the document.
  void applyEdit(YamlEditOperation operation) {
    _history.push(UndoEntry(
      oldState: operation,
      newState: operation,
    ));
    _document = operation.apply(_document);
    _revalidate();
    notifyListeners();
  }

  /// Undo the last edit.
  void undo() {
    if (!canUndo) return;
    var entry = _history.undo();
    if (entry == null) return;
    _document = entry.oldState.revert(_document);
    _revalidate();
    notifyListeners();
  }

  /// Redo the last undone edit.
  void redo() {
    if (!canRedo) return;
    var entry = _history.redo();
    if (entry == null) return;
    _document = entry.newState.apply(_document);
    _revalidate();
    notifyListeners();
  }

  /// Replace the entire YAML content.
  void setYaml(String yaml) {
    var newDoc = YamlDocumentModel.parse(yaml);
    var operation = YamlEditOperation(
      kind: YamlEditKind.replaceDocument,
      path: [],
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Set a value at a specific path.
  ///
  /// Path is a list of keys, e.g. `['prompt', 'meta-data', 'name']`.
  void setValue(List<String> path, Object? value) {
    var newDoc = _document.withValueAt(_toDocumentPath(path), value);
    var operation = YamlEditOperation(
      kind: YamlEditKind.setValue,
      path: path,
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Replace a subtree at [path] with a raw YAML [fragment], preserving
  /// the fragment's exact formatting (block scalars, quoting, indentation).
  ///
  /// Unlike [setValue], this does not parse the fragment to a Dart value first.
  /// Multiline block scalars (`|`, `>`) and other YAML formatting survive
  /// round-trips through the editor without being collapsed to quoted strings.
  void replaceSubtree(List<String> path, String fragment) {
    var newDoc = _document.replaceSubtreeRaw(_toDocumentPath(path), fragment);
    var operation = YamlEditOperation(
      kind: YamlEditKind.setValue,
      path: path,
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Insert a new key at a specific path based on schema suggestions.
  void insertKey(List<String> parentPath, String key, Object? defaultValue) {
    var newDoc = _document.withInsertedKey(
      _toDocumentPath(parentPath),
      key,
      defaultValue,
    );
    var operation = YamlEditOperation(
      kind: YamlEditKind.insertKey,
      path: [...parentPath, key],
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Remove a key at a specific path.
  void removeKey(List<String> path) {
    var newDoc = _document.withRemovedKey(_toDocumentPath(path));
    var operation = YamlEditOperation(
      kind: YamlEditKind.removeKey,
      path: path,
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  // ---------------------------------------------------------------------------
  // List operations
  // ---------------------------------------------------------------------------

  /// Insert a new item into a list at a given index.
  ///
  /// [listPath] is the path to the parent list node.
  void insertListItem(List<String> listPath, int index, Object? value) {
    var newDoc =
        _document.withInsertedIntoList(_toDocumentPath(listPath), index, value);
    var operation = YamlEditOperation(
      kind: YamlEditKind.insertListItem,
      path: [...listPath, index.toString()],
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Append an item to the end of a list.
  void appendListItem(List<String> listPath, Object? value) {
    var newDoc = _document.withAppendedToList(_toDocumentPath(listPath), value);
    var operation = YamlEditOperation(
      kind: YamlEditKind.insertListItem,
      path: listPath,
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Move a list item from [oldIndex] to [newIndex].
  ///
  /// [listPath] is the path to the parent list node.
  void moveListItem(List<String> listPath, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final docPath = _toDocumentPath(listPath);
    var value = _document.valueOf([...docPath, oldIndex]);
    // Remove then insert — build a single operation from before/after
    var removed = _document.withRemovedFromList([...docPath, oldIndex]);
    var adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    var newDoc = removed.withInsertedIntoList(docPath, adjustedIndex, value);
    var operation = YamlEditOperation(
      kind: YamlEditKind.reorderKeys,
      path: listPath,
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Get the number of items in a list at [listPath].
  ///
  /// Returns 0 if the path doesn't exist or isn't a list.
  int listLength(List<String> listPath) {
    var node = _document.nodeAt(_toDocumentPath(listPath));
    if (node == null) return 0;
    var value = node.value;
    if (value is List) return value.length;
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Map key insertion at position
  // ---------------------------------------------------------------------------

  /// Insert a new key adjacent to an existing key in a map.
  ///
  /// [siblingPath] is the full path to the reference key.
  /// When [above] is true the new key is inserted before the sibling;
  /// otherwise it is inserted after.
  void insertKeyAdjacent(
    List<String> siblingPath,
    String newKey,
    Object? value, {
    bool above = false,
  }) {
    // Fall back to normal insert — yaml_edit doesn't expose positional insert
    // for maps, so we re-serialize with the desired key order.
    var parentPath = siblingPath.sublist(0, siblingPath.length - 1);
    var newDoc =
        _document.withInsertedKey(_toDocumentPath(parentPath), newKey, value);
    var operation = YamlEditOperation(
      kind: YamlEditKind.insertKey,
      path: [...parentPath, newKey],
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Force revalidation of the current document against the schema.
  ///
  /// Normally called automatically on every edit, but can be called
  /// manually when the schema interpretation changes.
  void revalidate() {
    _revalidate();
    notifyListeners();
  }

  /// Get schema-based suggestions for keys that can be added at [parentPath].
  List<String> suggestedKeys(List<String> parentPath) {
    final schema = _schema;
    if (schema == null) return [];
    return schema.suggestedKeysAt(parentPath, _document);
  }

  /// Get the schema node for a given path.
  SchemaNode? schemaNodeAt(List<String> path) {
    return _schema?.nodeAt(path);
  }

  /// Internal: revalidate the document and update caches.
  void _revalidate() {
    final schema = _schema;
    if (schema == null) {
      _cachedErrors = [];
      _propagatedErrors = {};
      return;
    }
    _cachedErrors = schema.validate(_document);
    _propagatedErrors = ErrorPropagator.propagate(_cachedErrors);
  }

  @override
  void dispose() {
    _history.clear();
    super.dispose();
  }

  List<Object> _toDocumentPath(List<String> path) {
    return path
        .map<Object>((segment) => int.tryParse(segment) ?? segment)
        .toList(growable: false);
  }
}

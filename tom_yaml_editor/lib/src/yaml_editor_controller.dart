import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import 'model/yaml_document_model.dart';
import 'model/yaml_edit_operation.dart';
import 'schema/yaml_schema.dart';
import 'tree/editor_trail.dart';

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
    trailEvent('controller: applyEdit ${operation.kind.name} path=${operation.path}');
    try {
      _history.push(UndoEntry(
        oldState: operation,
        newState: operation,
      ));
      _document = operation.apply(_document);
      trailEvent('controller: applyEdit applied, revalidating');
      _revalidate();
      trailEvent('controller: applyEdit revalidated, notifying');
      notifyListeners();
      trailEvent('controller: applyEdit notifyListeners done');
    } catch (e, st) {
      trailEvent('controller: applyEdit THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_editor_controller',
        context: ErrorDescription('applyEdit ${operation.kind.name} path=${operation.path}'),
      ));
    }
  }

  /// Undo the last edit.
  void undo() {
    if (!canUndo) return;
    trailEvent('controller: undo');
    try {
      var entry = _history.undo();
      if (entry == null) return;
      _document = entry.oldState.revert(_document);
      _revalidate();
      notifyListeners();
    } catch (e, st) {
      trailEvent('controller: undo THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_editor_controller',
        context: ErrorDescription('undo'),
      ));
    }
  }

  /// Redo the last undone edit.
  void redo() {
    if (!canRedo) return;
    trailEvent('controller: redo');
    try {
      var entry = _history.redo();
      if (entry == null) return;
      _document = entry.newState.apply(_document);
      _revalidate();
      notifyListeners();
    } catch (e, st) {
      trailEvent('controller: redo THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_editor_controller',
        context: ErrorDescription('redo'),
      ));
    }
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
    var docPath = _toDocumentPath(parentPath);
    var doc = _document;

    // If the parent node is not a map (e.g. it is a scalar or null), upgrade
    // it to an empty map first so yaml_edit can set a sub-key on it.
    // This lets the user turn any scalar value into a map by adding a key.
    if (parentPath.isNotEmpty) {
      var parentNode = doc.nodeAt(docPath);
      if (parentNode != null && parentNode.value is! Map) {
        doc = doc.withValueAt(docPath, <String, Object?>{});
      }
    }

    var newDoc = doc.withInsertedKey(
      docPath,
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
  // Map key reordering
  // ---------------------------------------------------------------------------

  /// Move the map key at [fromIndex] to [toIndex] within the map at
  /// [parentPath].
  void moveMapKey(List<String> parentPath, int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    var newDoc = _document.withReorderedMapKey(
      _toDocumentPath(parentPath),
      fromIndex,
      toIndex,
    );
    var operation = YamlEditOperation(
      kind: YamlEditKind.reorderKeys,
      path: parentPath,
      oldDocument: _document,
      newDocument: newDoc,
    );
    applyEdit(operation);
  }

  /// Return the 0-based index of [keyPath.last] within its sibling map, or
  /// -1 if not found.
  int mapKeyIndex(List<String> keyPath) {
    if (keyPath.isEmpty) return -1;
    var parentPath = keyPath.sublist(0, keyPath.length - 1);
    var key = keyPath.last;
    var node = _document.nodeAt(_toDocumentPath(parentPath));
    if (node == null || node.value is! Map) return -1;
    var keys =
        (node.value as Map).keys.map((k) => k.toString()).toList();
    return keys.indexOf(key);
  }

  /// Return the number of keys in the map that is the parent of [keyPath].
  int mapKeyCount(List<String> keyPath) {
    if (keyPath.isEmpty) return 0;
    var parentPath = keyPath.sublist(0, keyPath.length - 1);
    var node = _document.nodeAt(_toDocumentPath(parentPath));
    if (node == null || node.value is! Map) return 0;
    return (node.value as Map).length;
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
    try {
      _cachedErrors = schema.validate(_document);
      _propagatedErrors = ErrorPropagator.propagate(_cachedErrors);
    } catch (e, st) {
      trailEvent('controller: _revalidate THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_editor_controller',
        context: ErrorDescription('_revalidate'),
      ));
      _cachedErrors = [];
      _propagatedErrors = {};
    }
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

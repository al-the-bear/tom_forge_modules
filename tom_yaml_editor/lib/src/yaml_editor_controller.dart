import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextSelection;
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart' show loadYamlNode;

import 'model/yaml_document_model.dart';
import 'model/yaml_edit_operation.dart';
import 'schema/yaml_schema.dart';
import 'tree/editor_trail.dart';

/// Controller for the YAML schema editor: the document, its one history, its
/// saved state, its mode, and validation.
///
/// It keeps the Forge history contract (tom_forge_ui's
/// `editor_history_contract.md`). The document is its source text
/// ([sourceText]); every change — a tree edit, typing in source mode, an
/// undo — changes that text, and [ForgeTextHistory] records it: typing in
/// source mode and typing into one tree field are one entry per gesture, a
/// structural tree edit is one entry, and a change that changes nothing is
/// none. Source text that does not parse is a draft the history keeps like
/// any other text, so undo and redo never lose it; the tree shows the last
/// text that parsed ([document]). Dirty is measured against the saved text
/// ([ForgeSavedMarker]). Every view — tree or source, main or split copy —
/// reads the one controller, so they share one history and one [textMode].
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

  /// The document's text as the source view shows it and a save writes it:
  /// the last parsed [document]'s text, or a draft that does not parse.
  String _source;

  /// Why [_source] does not parse, or null.
  String? _parseError;

  /// The document's one history, over [_source].
  late final ForgeTextHistory _history;

  /// Dirty against the saved text.
  late final ForgeSavedMarker<String> _saved;

  /// The tree field whose typing the pending history entry holds, so a
  /// different field starts a new entry.
  List<String>? _pendingFieldPath;

  bool _textMode = false;

  /// Cached validation errors, recomputed on every document change.
  List<ValidationError> _cachedErrors = [];

  /// Propagated error map for tree decoration.
  Map<String, List<ValidationError>> _propagatedErrors = {};

  /// The most recently applied edit operation (for UI to adjust state).
  YamlEditOperation? _lastOperation;

  /// Creates a controller with optional initial YAML and schema.
  YamlEditorController({
    String initialYaml = '',
    YamlSchema? schema,
    this.uri,
    int maxUndoHistory = ForgeTextDefaults.defaultMaxUndoHistory,
  })  : _document = YamlDocumentModel.parse(initialYaml),
        _source = initialYaml,
        _schema = schema {
    _history = ForgeTextHistory(
      ForgeTextState(initialYaml, const TextSelection.collapsed(offset: 0)),
      maxEntries: maxUndoHistory,
    );
    _saved = ForgeSavedMarker(initialYaml);
    _revalidate();
  }

  /// Optional URI associated with this editor's document.
  Uri? uri;

  /// Whether the document differs from the saved text.
  ValueListenable<bool> get isDirty => _saved.isDirty;

  /// The document as it is now is saved: the typing in progress ends and
  /// the saved marker moves. The history stays.
  void markClean() {
    flush();
    _saved.markSaved(_source);
  }

  /// The YAML text of the last [document] that parsed.
  String get yamlText => _document.toYamlString();

  /// The document's text: what the source view shows and a save writes —
  /// [yamlText], or a draft that does not parse ([parseError]).
  String get sourceText => _source;

  /// The selection in the source text as the history last heard it.
  TextSelection get sourceSelection => _history.current.selection;

  /// Why [sourceText] does not parse, or null when it does.
  String? get parseError => _parseError;

  /// Whether the editor shows the source text (true) or the tree. One mode
  /// for every view of the document. Switching ends the typing in progress;
  /// leaving source mode needs source that parses.
  bool get textMode => _textMode;
  set textMode(bool value) {
    if (value == _textMode) return;
    if (!value && _parseError != null) return;
    flush();
    _textMode = value;
    notifyListeners();
  }

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

  /// Ends the typing in progress (source or tree field): a history boundary
  /// — save, mode switch, focus leaving a field.
  void flush() {
    _history.flush();
    _pendingFieldPath = null;
  }

  /// The most recent edit operation (cleared after rebuild).
  ///
  /// Used by the UI to adjust expansion state for index shifts.
  /// Returns null if no operation is pending or was cleared.
  YamlEditOperation? get lastOperation => _lastOperation;

  /// Clear the last operation marker.
  void clearLastOperation() => _lastOperation = null;

  /// Content arrived from outside the history — a reload, an external change
  /// taken, a revision restore: the document becomes [yaml], it is the saved
  /// state, and the history is cleared.
  void replaceContent(String yaml) {
    _setSource(yaml);
    _history.replace(ForgeTextState.atEnd(yaml));
    _pendingFieldPath = null;
    _lastOperation = null;
    _saved.markSaved(yaml);
    _revalidate();
    notifyListeners();
  }

  /// How many edits the history keeps (`ForgeTextSettings.maxUndoHistory`).
  int get maxUndoHistory => _history.maxEntries;
  set maxUndoHistory(int value) => _history.maxEntries = value;

  /// Apply an edit operation to the document.
  ///
  /// The edit is recorded only once it applied and only when it changed the
  /// text. A [YamlEditKind.setValue] edit is typing into one tree field: edits
  /// of the same field with no pause between them are one history entry
  /// (the gesture); every other kind is an entry of its own.
  void applyEdit(YamlEditOperation operation) {
    trailEvent('controller: applyEdit ${operation.kind.name} path=${operation.path}');
    try {
      final text = operation.newDocument.toYamlString();
      if (text == _source) return;
      final field =
          operation.kind == YamlEditKind.setValue ? operation.path : null;
      if (field == null || !_samePath(field, _pendingFieldPath)) flush();
      _document = operation.apply(_document);
      _source = text;
      _parseError = null;
      _lastOperation = operation; // Store for UI to adjust expansion state
      _history.edited(ForgeTextState(text, _caretWithin(text)));
      if (field == null) {
        _history.flush();
      } else {
        _pendingFieldPath = field;
      }
      _changed();
    } catch (e, st) {
      trailEvent('controller: applyEdit THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_editor_controller',
        context: ErrorDescription('applyEdit ${operation.kind.name} path=${operation.path}'),
      ));
    }
  }

  /// The source view's text changed to [text] by typing (the edit applied):
  /// one history entry per gesture. Text that does not parse is kept as the
  /// document's draft; the tree keeps the last text that parsed.
  void editSource(String text, TextSelection selection) {
    if (text == _source) {
      selectSource(selection);
      return;
    }
    if (_pendingFieldPath != null) flush();
    _setSource(text);
    _lastOperation = null;
    _history.edited(ForgeTextState(text, selection));
    _changed();
  }

  /// The caret moved in the source view without the text changing: the
  /// typing gesture in progress ends.
  void selectSource(TextSelection selection) => _history.selected(selection);

  /// Undo the last edit.
  void undo() {
    trailEvent('controller: undo');
    _pendingFieldPath = null;
    if (_history.undo(_restore)) _changed();
  }

  /// Redo the last undone edit.
  void redo() {
    trailEvent('controller: redo');
    _pendingFieldPath = null;
    if (_history.redo(_restore)) _changed();
  }

  void _restore(ForgeTextState state) {
    _setSource(state.text);
    _lastOperation = null;
  }

  /// [text] becomes the source; the document follows when it parses.
  void _setSource(String text) {
    _source = text;
    try {
      if (text.isNotEmpty) loadYamlNode(text);
      _document = YamlDocumentModel.parse(text);
      _parseError = null;
    } catch (error) {
      _parseError = error.toString();
    }
  }

  /// After every change: dirty against the saved text, validation, views.
  void _changed() {
    _saved.compare(_source);
    if (_parseError == null) _revalidate();
    notifyListeners();
  }

  TextSelection _caretWithin(String text) {
    final at = _history.current.selection.baseOffset;
    return TextSelection.collapsed(offset: at.clamp(0, text.length));
  }

  static bool _samePath(List<String> a, List<String>? b) =>
      b != null && listEquals(a, b);

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
    trailEvent('ctrl: insertListItem path=$listPath index=$index value=${trailTruncate(value)}');
    
    // Validate index - valid insertion indices are 0..length (inclusive)
    final currentLength = listLength(listPath);
    if (index < 0 || index > currentLength) {
      trailEvent('ctrl: insertListItem ABORT invalid index (len=$currentLength)');
      return;
    }
    
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
    // Use insertListItem at current length instead of appendToList
    // to work around yaml_edit's buggy appendToList implementation
    final currentLength = listLength(listPath);
    insertListItem(listPath, currentLength, value);
  }

  /// Move a list item from [oldIndex] to [newIndex].
  ///
  /// [listPath] is the path to the parent list node.
  void moveListItem(List<String> listPath, int oldIndex, int newIndex) {
    trailEvent(
      'ctrl: moveListItem path=$listPath old=$oldIndex new=$newIndex',
    );
    if (oldIndex == newIndex) return;
    
    try {
      // Validate indices
      final currentLength = listLength(listPath);
      trailEvent('ctrl: moveListItem currentLength=$currentLength');
      if (oldIndex < 0 || oldIndex >= currentLength) {
        trailEvent('ctrl: moveListItem ABORT invalid oldIndex');
        return;
      }
      
      final docPath = _toDocumentPath(listPath);
      
      // Use atomic move operation to avoid intermediate state issues
      trailEvent('ctrl: moveListItem calling withMovedListItem');
      var newDoc = _document.withMovedListItem(docPath, oldIndex, newIndex);
      trailEvent('ctrl: moveListItem move done');
      
      // Calculate actual target index (clamped to valid range)
      final targetIndex = newIndex.clamp(0, currentLength - 1);

      var operation = YamlEditOperation(
        kind: YamlEditKind.moveListItem,
        path: listPath,
        oldDocument: _document,
        newDocument: newDoc,
        moveOldIndex: oldIndex,
        moveNewIndex: targetIndex,
      );
      applyEdit(operation);
      trailEvent('ctrl: moveListItem completed successfully');
    } catch (e, st) {
      trailEvent('ctrl: moveListItem EXCEPTION: $e');
      trailEvent('ctrl: moveListItem stack: ${st.toString().split('\n').take(5).join(' | ')}');
      rethrow;
    }
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
    if (siblingPath.isEmpty) return;
    var parentPath = siblingPath.sublist(0, siblingPath.length - 1);
    var siblingKey = siblingPath.last;
    var newDoc = _document.withInsertedKeyAdjacent(
      _toDocumentPath(parentPath),
      siblingKey,
      newKey,
      value,
      above: above,
    );
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
    _history.dispose();
    _saved.dispose();
    super.dispose();
  }

  List<Object> _toDocumentPath(List<String> path) {
    return path
        .map<Object>((segment) => int.tryParse(segment) ?? segment)
        .toList(growable: false);
  }
}

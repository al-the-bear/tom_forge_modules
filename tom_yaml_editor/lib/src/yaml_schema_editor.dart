import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'editors/editor_registry.dart';
import 'inspector/inspector_dialog.dart';
import 'inspector/inspector_layouts.dart';
import 'inspector/subtree_inspector.dart';
import 'integration/yaml_standalone_integration.dart';
import 'model/yaml_document_model.dart';
import 'model/yaml_edit_operation.dart';
import 'schema/schema_marker_generator.dart';
import 'schema/schema_walker.dart';
import 'text_editor/yaml_syntax_highlighter.dart';
import 'tree/editor_trail.dart';
import 'tree/list_node_row.dart';
import 'tree/map_node_row.dart';
import 'tree/yaml_tree_node_builder.dart';
import 'validation/validation_error_list.dart';
import 'yaml_editor_controller.dart';
import 'yaml_editor_theme.dart';

/// A non-destructive, schema-aware YAML editor widget.
///
/// Renders a YAML document as a structured tree with:
/// - Nested key/value pairs with proper indentation and tree lines
/// - Schema-based validation and construction help
/// - Convention-based embedded editors (e.g. `-dart` suffix → Dart editor)
/// - Collapse/expand for nested structures with state persistence
/// - Add/remove buttons for optional keys
/// - Keyboard navigation (arrow keys, Enter, Space, Escape, Tab)
/// - Inline validation badges with error propagation
///
/// ```dart
/// YamlSchemaEditor(
///   controller: myController,
///   theme: YamlEditorTheme.dark(),
///   editorRegistry: EditorRegistry.defaults(),
/// )
/// ```
class YamlSchemaEditor extends StatefulWidget {
  /// Controller managing document state, undo/redo, and validation.
  final YamlEditorController controller;

  /// Visual theme for the editor.
  final YamlEditorTheme theme;

  /// Registry of embedded editors keyed by suffix convention.
  final EditorRegistry editorRegistry;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Callback when the YAML content changes.
  final ValueChanged<String>? onChanged;

  /// Callback when a validation error occurs.
  final ValueChanged<List<ValidationError>>? onValidationChanged;

  /// The inspector mode to use when inspecting a subtree.
  ///
  /// Defaults to [SubtreeInspectorMode.bottomSheet].
  final SubtreeInspectorMode inspectorMode;

  /// Position for the validation error list, or null to hide it.
  final ErrorListPosition? errorListPosition;

  /// Whether to highlight tree rows that have errors.
  final bool highlightErrorRows;

  /// Optional integration with the Forge shell.
  ///
  /// When null, a [YamlStandaloneIntegration] is created automatically
  /// with the editor's controller and theme-derived text settings.
  /// When provided, the given integration is used directly.
  final ForgeEditorIntegration? integration;

  const YamlSchemaEditor({
    super.key,
    required this.controller,
    this.theme = const YamlEditorTheme(),
    EditorRegistry? editorRegistry,
    this.readOnly = false,
    this.onChanged,
    this.onValidationChanged,
    this.inspectorMode = SubtreeInspectorMode.bottomSheet,
    this.errorListPosition,
    this.highlightErrorRows = false,
    this.integration,
  }) : editorRegistry = editorRegistry ?? const EditorRegistry();

  @override
  State<YamlSchemaEditor> createState() => _YamlSchemaEditorState();
}

class _YamlSchemaEditorState extends State<YamlSchemaEditor> {
  late TreeController<YamlTreeData> _treeController;
  late SchemaWalker? _schemaWalker;
  final FocusNode _focusNode = FocusNode();

  /// The active Forge editor integration.
  late ForgeEditorIntegration _integration;

  /// Whether we own (created) the integration and must dispose it.
  bool _ownsIntegration = false;

  /// Set of node IDs that the user has explicitly collapsed.
  ///
  /// All container nodes are EXPANDED by default. Only nodes present in this
  /// set are kept collapsed across document rebuilds. Newly inserted map/list
  /// nodes therefore auto-open without any special handling.
  final Set<String> _persistedCollapsed = {};

  /// Whether the first-level-only expansion has been applied for the current
  /// document.  Reset when a new document is loaded (controller swap).
  bool _initialExpansionApplied = false;

  /// The path currently being inspected, or null if no inspector is open.
  List<String>? _inspectedPath;

  /// Computed key label widths per parent group (auto-sizing mode).
  ///
  /// Key: parent path joined by '/', Value: pixel width for key labels.
  Map<String, double> _computedKeyWidths = {};

  bool _textInputFocused = false;
  bool _textMode = false;
  String _textDraft = '';
  String? _textParseError;
  List<TextMarker> _textMarkers = const [];

  /// Heartbeat timer: fires every second to show the main isolate is still
  /// alive. If [YE] heartbeats stop appearing after a trail event, that event's
  /// code path is blocking the isolate (infinite loop or blocking IO).
  Timer? _heartbeat;

  /// Saved FlutterError handler so we can restore it on dispose.
  void Function(FlutterErrorDetails)? _prevFlutterErrorHandler;

  @override
  void initState() {
    super.initState();
    if (kYamlEditorDebug) {
      // Intercept all Flutter framework errors and print them to the trail.
      _prevFlutterErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        // Truncate error to avoid flooding console with YAML content
        var errorStr = details.exceptionAsString();
        if (errorStr.length > 200) {
          errorStr = '${errorStr.substring(0, 200)}...';
        }
        trailEvent('FlutterError: $errorStr');
        // Print simplified stack trace
        var stack = details.stack?.toString().split('\n').take(10).join('\n');
        if (stack != null) {
          trailEvent('Stack (first 10 frames):\n$stack');
        }
        // Don't call previous handler - it prints the full verbose error
      };
      // Heartbeat: confirms the main isolate is alive every second.
      if (kYamlEditorHeartbeat) {
        _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
          trailEvent('heartbeat');
        });
      }
    }
    _schemaWalker = widget.controller.schema != null
        ? SchemaWalker(widget.controller.schema!)
        : null;
    _textDraft = widget.controller.yamlText;
    _treeController = TreeController<YamlTreeData>(roots: []);
    _setupIntegration();
    _rebuildTree();
    widget.controller.addListener(_onControllerChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
  }

  /// Sets up the Forge editor integration.
  ///
  /// If [widget.integration] is provided, uses it directly.
  /// Otherwise creates a [YamlStandaloneIntegration] with theme-derived
  /// text settings and registers YAML-specific actions.
  void _setupIntegration() {
    try {
      if (widget.integration != null) {
        _integration = widget.integration!;
        _ownsIntegration = false;
      } else {
        final settings = YamlEditorDefaults.forgeTextSettingsFrom(widget.theme);
        _integration = YamlStandaloneIntegration(
          controller: widget.controller,
          textSettings: settings,
        );
        _ownsIntegration = true;
      }
      _registerActions();

      // Wire undo bridge: when the controller pushes an undo entry,
      // notify the integration so the shell undo manager stays in sync.
      widget.controller.onUndoPush = (description) {
        _integration.notifyTextEdit(label: description);
      };

      trailEvent('setupIntegration: done (owned=$_ownsIntegration)');
    } catch (e) {
      trailEvent('setupIntegration: THREW $e');
    }
  }

  /// Registers YAML-specific actions with the integration.
  void _registerActions() {
    try {
      _integration.registerAction(
        YamlEditorActions.toggleTextModeActionId,
        _toggleTextMode,
        isEnabled: () => true,
      );
      _integration.registerAction(
        StandardEditingActions.undoActionId,
        () => widget.controller.undo(),
        isEnabled: () => widget.controller.canUndo,
      );
      _integration.registerAction(
        StandardEditingActions.redoActionId,
        () => widget.controller.redo(),
        isEnabled: () => widget.controller.canRedo,
      );
      trailEvent('registerActions: done');
    } catch (e) {
      trailEvent('registerActions: THREW $e');
    }
  }

  @override
  void didUpdateWidget(YamlSchemaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _schemaWalker = widget.controller.schema != null
          ? SchemaWalker(widget.controller.schema!)
          : null;

      // New controller = new document source; reset ALL expansion state so the
      // new document opens with only first-level expanded.
      _persistedCollapsed.clear();
      _initialExpansionApplied = false;
      _treeController.dispose();
      _treeController = TreeController<YamlTreeData>(roots: []);

      if (!_textMode) {
        _textDraft = widget.controller.yamlText;
      }

      // Re-setup integration for the new controller
      if (_ownsIntegration) {
        _integration.dispose();
      }
      _setupIntegration();

      _rebuildTree();
    } else if (oldWidget.integration != widget.integration) {
      // Integration changed without controller change
      if (_ownsIntegration) {
        _integration.dispose();
      }
      _setupIntegration();
    }
  }

  @override
  void dispose() {
    if (_ownsIntegration) {
      _integration.dispose();
    }
    _heartbeat?.cancel();
    if (kYamlEditorDebug) {
      FlutterError.onError = _prevFlutterErrorHandler;
    }
    widget.controller.removeListener(_onControllerChanged);
    _treeController.dispose();
    _focusNode.dispose();
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    super.dispose();
  }

  void _onPrimaryFocusChanged() {
    var focusContext = FocusManager.instance.primaryFocus?.context;
    var isTextFocused = focusContext?.widget is EditableText;
    if (isTextFocused != _textInputFocused && mounted) {
      trailEvent('focusChange: textFocused $isTextFocused (was $_textInputFocused)');
      setState(() {
        _textInputFocused = isTextFocused;
      });
    }
  }

  void _onControllerChanged() {
    trailEvent('onControllerChanged: start');
    // Adjust expansion state for list index shifts BEFORE rebuilding tree
    _adjustExpansionForLastOperation();
    try {
      _rebuildTree();
      trailEvent('onControllerChanged: rebuildTree done');
    } catch (e, st) {
      trailEvent('onControllerChanged: rebuildTree THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_schema_editor',
        context: ErrorDescription('_rebuildTree in _onControllerChanged'),
      ));
    }
    if (!_textMode) {
      _textDraft = widget.controller.yamlText;
      try {
        final preview = _computeTextDiagnostics(_textDraft);
        _textParseError = preview.parseError;
        _textMarkers = preview.markers;
      } catch (e, st) {
        trailEvent('onControllerChanged: _computeTextDiagnostics THREW $e');
        FlutterError.reportError(FlutterErrorDetails(
          exception: e, stack: st,
          library: 'yaml_schema_editor',
          context: ErrorDescription('_computeTextDiagnostics in _onControllerChanged'),
        ));
      }
    }
    if (mounted) {
      // Guard against being called while the framework tree is locked
      // (e.g. when a descendent value-editor flushes uncommitted edits
      // from its dispose — which happens during _InactiveElements._unmountAll
      // inside BuildOwner.lockState). In that phase setState() would throw.
      // Detect this by checking the scheduler phase and deffer to the next
      // frame when the tree is locked.
      final phase = SchedulerBinding.instance.schedulerPhase;
      final locked = phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.postFrameCallbacks;
      trailEvent('onControllerChanged: setState phase=$phase locked=$locked');
      if (locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
      trailEvent('onControllerChanged: setState done');
    }
    try {
      widget.onChanged?.call(widget.controller.yamlText);
      widget.onValidationChanged?.call(widget.controller.errors);
    } catch (e, st) {
      trailEvent('onControllerChanged: onChanged callback THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_schema_editor',
        context: ErrorDescription('onChanged/onValidationChanged callback'),
      ));
    }
    trailEvent('onControllerChanged: done');
  }

  void _toggleTextMode() {
    if (_textMode) {
      if (_textParseError != null) return;
      if (_textParseError == null && _textDraft != widget.controller.yamlText) {
        widget.controller.setYaml(_textDraft);
      }
      setState(() {
        _textMode = false;
      });
      return;
    }

    final draft = widget.controller.yamlText;
    final diagnostics = _computeTextDiagnostics(draft);
    setState(() {
      _inspectedPath = null;
      _textMode = true;
      _textDraft = draft;
      _textParseError = diagnostics.parseError;
      _textMarkers = diagnostics.markers;
    });
  }

  void _onTextDraftChanged(String text) {
    final diagnostics = _computeTextDiagnostics(text);
    setState(() {
      _textDraft = text;
      _textParseError = diagnostics.parseError;
      _textMarkers = diagnostics.markers;
    });

    if (_textParseError == null && text != widget.controller.yamlText) {
      widget.controller.setYaml(text);
    }
  }

  ({String? parseError, List<TextMarker> markers}) _computeTextDiagnostics(
    String text,
  ) {
    if (text.isEmpty) return (parseError: null, markers: const []);

    try {
      loadYamlNode(text);
    } catch (error) {
      int start = 0;
      int end = 1;
      int line = 1;
      int column = 1;
      if (error is YamlException && error.span != null) {
        start = error.span!.start.offset;
        end =
            error.span!.end.offset > start ? error.span!.end.offset : start + 1;
        line = error.span!.start.line + 1;
        column = error.span!.start.column + 1;
      }
      return (
        parseError: error.toString(),
        markers: [
          TextMarker(
            start: start,
            end: end,
            message: error.toString(),
            type: TextMarkerType.error,
            line: line,
            column: column,
          ),
        ],
      );
    }

    final schema = widget.controller.schema;
    if (schema == null) return (parseError: null, markers: const []);

    final doc = YamlDocumentModel.parse(text);
    final errors = schema.validate(doc);
    return (
      parseError: null,
      markers: SchemaMarkerGenerator.generate(yamlText: text, errors: errors),
    );
  }

  /// Rebuild the tree from the current document, preserving expand state.
  ///
  /// On the FIRST build after a document load, only depth-0 (top-level)
  /// containers are opened.  After that, the user's explicit expand/collapse
  /// choices (tracked in [_persistedCollapsed]) are respected, and newly
  /// inserted containers auto-open.
  void _rebuildTree() {
    trailEvent('rebuildTree: start');
    try {
      var builder = YamlTreeNodeBuilder(
        document: widget.controller.document,
        schemaWalker: _schemaWalker,
        errors: widget.controller.errors,
      );
      trailEvent('rebuildTree: calling builder.build()');
      var roots = builder.build();
      trailEvent('rebuildTree: build() done, roots=${roots.length}');

      if (!_initialExpansionApplied) {
        // First load: expand only the top level (depth == 0).
        for (var node in _allIncludingRoots(roots)) {
          node.isExpanded = !node.isLeaf && node.depth == 0;
        }
        _initialExpansionApplied = true;
      } else {
        // Subsequent rebuilds: containers expanded by default; only nodes
        // explicitly collapsed by the user stay closed.
        for (var node in _allIncludingRoots(roots)) {
          node.isExpanded =
              !node.isLeaf && !_persistedCollapsed.contains(node.id);
        }
      }
      trailEvent('rebuildTree: expansion applied, setting treeController.roots');
      _treeController.roots = roots;
      trailEvent('rebuildTree: calling _computeKeyWidths');
      _computeKeyWidths();
      trailEvent('rebuildTree: done');
    } catch (e, st) {
      trailEvent('rebuildTree: THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_schema_editor',
        context: ErrorDescription('_rebuildTree'),
      ));
    }
  }

  /// Adjust expansion state when list items shift due to insert or move.
  ///
  /// When a list item is inserted at index N:
  /// 1. All items at indices >= N shift to index+1
  /// 2. IDs in _persistedCollapsed must shift accordingly
  /// 3. TreeController's internal _expandedIds must also shift
  /// 4. The new item at N should start collapsed
  ///
  /// When a list is reordered (move):
  /// - We don't have exact old/new indices in the operation
  /// - Collapse all expanded items in that list to prevent state transfer
  void _adjustExpansionForLastOperation() {
    final op = widget.controller.lastOperation;
    if (op == null) return;
    widget.controller.clearLastOperation();

    if (op.kind == YamlEditKind.moveListItem) {
      // For moves, swap expansion states between old/new indices
      _adjustExpansionForMove(op);
      return;
    }

    // Only care about list inserts beyond this point
    if (op.kind != YamlEditKind.insertListItem) {
      return;
    }

    // Path like ['workflow', 'steps', '1'] - last element is the index
    if (op.path.isEmpty) return;
    final indexStr = op.path.last;
    final insertedIndex = int.tryParse(indexStr);
    if (insertedIndex == null) return;

    // Parent path prefix (e.g., 'workflow.steps.')
    final parentPath = op.path.sublist(0, op.path.length - 1);
    final prefix = '${parentPath.join('.')}.';

    // Find IDs that need to shift and track their expansion state
    final collapsedToShift = <String, String>{}; // oldId -> newId
    final expandedToShift = <String, String>{}; // oldId -> newId

    // Process _persistedCollapsed
    for (var id in _persistedCollapsed.toList()) {
      if (!id.startsWith(prefix)) continue;

      final suffix = id.substring(prefix.length);
      final dotPos = suffix.indexOf('.');
      final indexPart = dotPos >= 0 ? suffix.substring(0, dotPos) : suffix;
      final restPart = dotPos >= 0 ? suffix.substring(dotPos) : '';
      final oldIndex = int.tryParse(indexPart);
      if (oldIndex == null) continue;

      if (oldIndex >= insertedIndex) {
        final newId = '$prefix${oldIndex + 1}$restPart';
        collapsedToShift[id] = newId;
      }
    }

    // Find expanded IDs that need to shift (check TreeController)
    for (var node in _allIncludingRoots(_treeController.roots)) {
      final id = node.id;
      if (!id.startsWith(prefix)) continue;
      if (_persistedCollapsed.contains(id)) continue; // Already handled

      final suffix = id.substring(prefix.length);
      final dotPos = suffix.indexOf('.');
      final indexPart = dotPos >= 0 ? suffix.substring(0, dotPos) : suffix;
      final restPart = dotPos >= 0 ? suffix.substring(dotPos) : '';
      final oldIndex = int.tryParse(indexPart);
      if (oldIndex == null) continue;

      if (oldIndex >= insertedIndex && _treeController.isExpanded(id)) {
        final newId = '$prefix${oldIndex + 1}$restPart';
        expandedToShift[id] = newId;
      }
    }

    // Update _persistedCollapsed
    for (var entry in collapsedToShift.entries) {
      _persistedCollapsed.remove(entry.key);
      _persistedCollapsed.add(entry.value);
    }

    // Update TreeController's internal state:
    // Collapse old IDs so they don't transfer to new items at same position
    for (var oldId in expandedToShift.keys) {
      _treeController.collapse(oldId);
    }

    // Add newly inserted item to collapsed set so it stays closed
    final newItemId = op.path.join('.');
    _persistedCollapsed.add(newItemId);
    // Also collapse in TreeController in case it somehow got the ID
    _treeController.collapse(newItemId);

    trailEvent('adjustExpansion: shifted ${collapsedToShift.length} collapsed, '
        '${expandedToShift.length} expanded, collapsed $newItemId');
  }

  /// Handle expansion state for list move operations.
  ///
  /// When item moves from oldIndex to newIndex, expansion states shift:
  /// - The moved item keeps its state at the new position
  /// - Items in between shift by one position
  void _adjustExpansionForMove(YamlEditOperation op) {
    final oldIndex = op.moveOldIndex;
    final newIndex = op.moveNewIndex;
    if (oldIndex == null || newIndex == null || oldIndex == newIndex) return;

    final prefix = '${op.path.join('.')}.';

    // Build map of old index -> isCollapsed for list items
    final collapsedByOldIndex = <int, bool>{};
    final expandedByOldIndex = <int, bool>{};

    // Check _persistedCollapsed for collapsed state
    for (var id in _persistedCollapsed.toList()) {
      if (!id.startsWith(prefix)) continue;
      final suffix = id.substring(prefix.length);
      final dotPos = suffix.indexOf('.');
      final indexPart = dotPos >= 0 ? suffix.substring(0, dotPos) : suffix;
      final idx = int.tryParse(indexPart);
      if (idx != null) {
        collapsedByOldIndex[idx] = true;
      }
    }

    // Check TreeController for expanded state (items not in _persistedCollapsed)
    for (var node in _allIncludingRoots(_treeController.roots)) {
      final id = node.id;
      if (!id.startsWith(prefix)) continue;
      final suffix = id.substring(prefix.length);
      final dotPos = suffix.indexOf('.');
      final indexPart = dotPos >= 0 ? suffix.substring(0, dotPos) : suffix;
      final idx = int.tryParse(indexPart);
      if (idx != null && !collapsedByOldIndex.containsKey(idx)) {
        expandedByOldIndex[idx] = _treeController.isExpanded(id);
      }
    }

    // Calculate new indices after move
    // Moving from oldIndex to newIndex means:
    // - item at oldIndex -> newIndex
    // - items between shift by 1
    int oldToNew(int i) {
      if (i == oldIndex) return newIndex;
      if (oldIndex < newIndex) {
        // Moving down: items in (oldIndex, newIndex] shift left by 1
        if (i > oldIndex && i <= newIndex) return i - 1;
      } else {
        // Moving up: items in [newIndex, oldIndex) shift right by 1
        if (i >= newIndex && i < oldIndex) return i + 1;
      }
      return i;
    }

    // Collapse all current IDs in TreeController first (clear state)
    for (var node in _allIncludingRoots(_treeController.roots)) {
      final id = node.id;
      if (id.startsWith(prefix) && _treeController.isExpanded(id)) {
        _treeController.collapse(id);
      }
    }

    // Update _persistedCollapsed with new indices
    final newCollapsed = <String>{};
    for (var id in _persistedCollapsed.toList()) {
      if (!id.startsWith(prefix)) {
        newCollapsed.add(id);
        continue;
      }
      final suffix = id.substring(prefix.length);
      final dotPos = suffix.indexOf('.');
      final indexPart = dotPos >= 0 ? suffix.substring(0, dotPos) : suffix;
      final restPart = dotPos >= 0 ? suffix.substring(dotPos) : '';
      final oldIdx = int.tryParse(indexPart);
      if (oldIdx == null) {
        newCollapsed.add(id);
        continue;
      }
      final newIdx = oldToNew(oldIdx);
      newCollapsed.add('$prefix$newIdx$restPart');
    }
    _persistedCollapsed
      ..clear()
      ..addAll(newCollapsed);

    trailEvent('adjustExpansionForMove: $oldIndex->$newIndex');
  }

  void _setNodeExpanded(TreeNode<YamlTreeData> node, bool expanded) {
    if (node.children.isEmpty) return;
    final isCurrentlyExpanded = _treeController.isExpanded(node.id);
    if (expanded == isCurrentlyExpanded) return;

    if (expanded) {
      // Remove from collapsed set → node stays open on next rebuild.
      _persistedCollapsed.remove(node.id);
      _treeController.expand(node.id);
    } else {
      // Add to collapsed set → node stays closed on next rebuild.
      _persistedCollapsed.add(node.id);
      _treeController.collapse(node.id);
    }
  }

  void _setSubtreeExpanded(
    TreeNode<YamlTreeData> node,
    bool expanded, {
    bool includeRoot = true,
  }) {
    if (includeRoot && !node.isLeaf) {
      _setNodeExpanded(node, expanded);
    }
    for (var descendant in node.allDescendants.where((n) => !n.isLeaf)) {
      _setNodeExpanded(descendant, expanded);
    }
  }

  /// Auto-expand a node's parents when a new key is inserted.
  // ignore: unused_element
  void _revealNode(String id) {
    _treeController.revealNode(id);
    // Remove any ancestor that was in the collapsed set so it stays open.
    for (var node in _allIncludingRoots(_treeController.roots)) {
      if (_treeController.isExpanded(node.id)) {
        _persistedCollapsed.remove(node.id);
      }
    }
  }

  /// All nodes — both roots and their descendants.
  Iterable<TreeNode<YamlTreeData>> _allIncludingRoots(
      List<TreeNode<YamlTreeData>> roots) sync* {
    for (var root in roots) {
      yield root;
      yield* root.allDescendants;
    }
  }

  /// Descendants only (does NOT include the roots themselves).
  Iterable<TreeNode<YamlTreeData>> _allNodes(
      List<TreeNode<YamlTreeData>> roots) sync* {
    for (var root in roots) {
      yield* root.allDescendants;
    }
  }

  // -------------------------------------------------------------------------
  // Dynamic key width computation
  // -------------------------------------------------------------------------

  /// Recompute key label widths per sibling group.
  ///
  /// Uses all nodes (not just visible) so widths remain stable when
  /// expanding / collapsing sections.
  void _computeKeyWidths() {
    if (widget.theme.keyLabelWidth != null) {
      _computedKeyWidths = {};
      return;
    }
    try {
      var fonts = widget.theme.fonts;
      var groups = <String, double>{};
      var nodeCount = 0;

      for (var node in _allNodes(_treeController.roots)) {
        var data = node.data;
        // Only map entries have key labels that need alignment.
        if (data.kind == YamlNodeKind.listItem) continue;

        var parentPath = data.path.length > 1
            ? data.path.sublist(0, data.path.length - 1).join('/')
            : '';
        var keyWidth = _measureKeyText('${data.key}:', fonts);
        var current = groups[parentPath] ?? 0;
        if (keyWidth > current) groups[parentPath] = keyWidth;
        nodeCount++;
      }
      trailEvent('_computeKeyWidths: measured $nodeCount nodes');

      // Small buffer for required dot (6+4px) + breathing room.
      const badgePadding = 12.0;
      var minWidth = widget.theme.keyLabelMinWidth;
      _computedKeyWidths = groups.map(
        (k, v) => MapEntry(k, (v + badgePadding).clamp(minWidth, 400.0)),
      );
    } catch (e, st) {
      trailEvent('_computeKeyWidths: THREW $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e, stack: st,
        library: 'yaml_schema_editor',
        context: ErrorDescription('_computeKeyWidths'),
      ));
    }
  }

  /// Measure the pixel width of [text] using the theme's key font.
  double _measureKeyText(String text, YamlEditorFontSettings fonts) {
    var painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fonts.keyFontFamily,
          fontSize: fonts.keyFontSize,
          fontWeight: fonts.keyFontWeight,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    var width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    var theme = widget.theme;
    var treeTheme = TreeTheme(
      treeLineColor: theme.structureColors.treeLine,
      hoverColor: theme.colors.hoverColor,
      selectionColor: theme.colors.selectionColor,
      indentWidth: theme.indentWidth,
      showTreeLines: theme.showTreeLines,
      rowHeight: null, // Variable height for embedded editors
    );

    var treeWidget = Container(
      color: theme.colors.background,
      // Right padding is provided by the ListView inside TreeView (12 px) so
      // the overlay scrollbar thumb never hides action buttons.  Adding it
      // here too would create a visible gap between the scrollbar and the
      // editor content.
      padding: theme.editorPadding.copyWith(right: 0),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: TreeView<YamlTreeData>(
          controller: _treeController,
          theme: treeTheme,
          nodeBuilder: (context, node, isSelected) {
            return _buildNodeContent(node);
          },
          enableKeyboardNavigation: !_textInputFocused,
        ),
      ),
    );

    var treeView = treeWidget;

    Widget editorContent;
    if (_textMode) {
      editorContent = _buildTextModeEditor(theme);
    } else if (_inspectedPath == null) {
      editorContent = treeView;
    } else {
      switch (widget.inspectorMode) {
        case SubtreeInspectorMode.sidePanel:
          editorContent = InspectorSidePanel(
            controller: widget.controller,
            path: _inspectedPath!,
            theme: theme,
            treeView: treeView,
            readOnly: widget.readOnly,
            onClose: _closeInspector,
          );
        case SubtreeInspectorMode.bottomSheet:
          editorContent = InspectorBottomSheet(
            controller: widget.controller,
            path: _inspectedPath!,
            theme: theme,
            treeView: treeView,
            readOnly: widget.readOnly,
            onClose: _closeInspector,
          );
        case SubtreeInspectorMode.dialog:
          // Dialog is opened via _openInspector → showInspectorDialog
          editorContent = treeView;
      }
    }

    var mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildModeToolbar(theme),
        Expanded(child: editorContent),
      ],
    );

    // Wrap with optional error list
    var errorListPos = widget.errorListPosition;
    if (errorListPos == null || widget.controller.errors.isEmpty) {
      return mainContent;
    }

    var errorList = SizedBox(
      height: errorListPos == ErrorListPosition.bottom ? 160 : null,
      width: errorListPos == ErrorListPosition.side ? 280 : null,
      child: ValidationErrorList(
        errors: widget.controller.errors,
        theme: theme,
        onErrorTap: (error) {
          // Navigate to the error's node in the tree
          var pathHash = error.path.join('/');
          _treeController.select(pathHash);
          _revealNode(pathHash);
        },
      ),
    );

    if (errorListPos == ErrorListPosition.bottom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: mainContent),
          Divider(
            height: 1,
            color: theme.colors.separatorColor.withAlpha(80),
          ),
          errorList,
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: mainContent),
          VerticalDivider(
            width: 1,
            color: theme.colors.separatorColor.withAlpha(80),
          ),
          errorList,
        ],
      );
    }
  }

  Widget _buildModeToolbar(YamlEditorTheme theme) {
    final icon = _textMode ? Icons.account_tree : Icons.code;
    final tooltip = _textMode ? 'Switch to tree mode' : 'Switch to text mode';
    final label = _textMode ? 'Text mode' : 'Tree mode';
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(color: theme.colors.separatorColor.withAlpha(90)),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colors.hintColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            tooltip: tooltip,
            onPressed: _toggleTextMode,
            icon: Icon(icon, color: theme.colors.keyColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTextModeEditor(YamlEditorTheme theme) {
    final textEditorTheme = TextEditorTheme(
      background: theme.colors.background,
      textStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const [
          'JetBrains Mono',
          'Menlo',
          'Monaco',
          'Courier New',
        ],
        fontSize: theme.fonts.valueFontSize,
        color: theme.colors.valueColor,
        height: 1.4,
      ),
      lineNumberStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const [
          'JetBrains Mono',
          'Menlo',
          'Monaco',
          'Courier New',
        ],
        fontSize: theme.fonts.valueFontSize,
        color: theme.colors.hintColor,
        height: 1.4,
      ),
      gutterBackground: theme.colors.surface,
      gutterBorderColor: theme.colors.separatorColor.withAlpha(80),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextEditorCore(
            text: _textDraft,
            highlighter: YamlSyntaxHighlighter(
              colors: YamlHighlightColors(
                key: theme.colors.keyColor,
                string: theme.colors.valueColor,
                number: theme.colors.numberColor,
                boolean: theme.colors.boolColor,
                nullValue: theme.colors.nullColor,
                comment: theme.colors.commentColor,
                punctuation: theme.structureColors.collapseIcon,
                colon: theme.colors.warningColor,
                dash: theme.colors.boolColor,
                bracket: theme.colors.numberColor,
              ),
            ),
            markers: _textMarkers,
            onTextChanged: widget.readOnly ? null : _onTextDraftChanged,
            readOnly: widget.readOnly,
            theme: textEditorTheme,
          ),
        ),
        if (_textParseError != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colors.errorColor.withAlpha(30),
              border: Border(
                top: BorderSide(color: theme.colors.errorColor.withAlpha(120)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: theme.colors.errorColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'YAML parse error — fix before switching back to tree mode',
                    style: TextStyle(
                      color: theme.colors.errorColor,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Open the subtree inspector for the given [path].
  void _openInspector(List<String> path) {
    if (widget.inspectorMode == SubtreeInspectorMode.dialog) {
      // Dialog mode: launch modal dialog
      showInspectorDialog(
        context: context,
        controller: widget.controller,
        path: path,
        theme: widget.theme,
        readOnly: widget.readOnly,
      );
    } else {
      // Side panel or bottom sheet: update state
      setState(() {
        _inspectedPath = path;
      });
    }
  }

  /// Close the subtree inspector.
  void _closeInspector() {
    setState(() {
      _inspectedPath = null;
    });
  }

  Widget _buildNodeContent(TreeNode<YamlTreeData> node) {
    var data = node.data;

    // Look up computed key width for this node's parent group.
    double? keyWidth;
    if (widget.theme.keyLabelWidth == null) {
      var parentPath = data.path.length > 1
          ? data.path.sublist(0, data.path.length - 1).join('/')
          : '';
      keyWidth = _computedKeyWidths[parentPath];
    }

    // Collect context menu actions from the integration.
    final contextActions = _integration.supportedActions
        .where((a) => a.showInContextMenu)
        .toList();

    // Validation tooltip wrapping
    var directErrors = data.directErrors;
    Widget content;

    switch (data.kind) {
      case YamlNodeKind.listItem:
        content = ListNodeRow(
          node: node,
          controller: widget.controller,
          editorRegistry: widget.editorRegistry,
          schemaWalker: _schemaWalker,
          theme: widget.theme,
          readOnly: widget.readOnly,
          integrationActions: contextActions.isNotEmpty ? contextActions : null,
          onInspect: data.isContainer ? () => _openInspector(data.path) : null,
          canExpand: node.children.isNotEmpty,
          isExpanded: node.isExpanded,
          onExpand: node.children.isNotEmpty
              ? () => setState(() => _setNodeExpanded(node, true))
              : null,
          onCollapse: node.children.isNotEmpty
              ? () => setState(() => _setNodeExpanded(node, false))
              : null,
          onExpandAll: node.children.isNotEmpty
              ? () => setState(() => _setSubtreeExpanded(node, true))
              : null,
          onCollapseAll: node.children.isNotEmpty
              ? () => setState(() => _setSubtreeExpanded(node, false))
              : null,
          onDoubleTapToggle: node.children.isNotEmpty
              ? () => setState(() => _setNodeExpanded(node, !node.isExpanded))
              : null,
        );
      case YamlNodeKind.mapEntry:
      case YamlNodeKind.root:
        content = MapNodeRow(
          node: node,
          controller: widget.controller,
          editorRegistry: widget.editorRegistry,
          schemaWalker: _schemaWalker,
          theme: widget.theme,
          readOnly: widget.readOnly,
          isRoot: data.kind == YamlNodeKind.root,
          isTopLevel:
              data.kind == YamlNodeKind.mapEntry && data.path.length == 1,
          integrationActions: contextActions.isNotEmpty ? contextActions : null,
          onInspect: data.isContainer ? () => _openInspector(data.path) : null,
          canExpand: node.children.isNotEmpty,
          isExpanded: node.isExpanded,
          onExpand: node.children.isNotEmpty
              ? () => setState(() => _setNodeExpanded(node, true))
              : null,
          onCollapse: node.children.isNotEmpty
              ? () => setState(() => _setNodeExpanded(node, false))
              : null,
          onExpandAll: node.children.isNotEmpty
              ? () => setState(() => _setSubtreeExpanded(node, true))
              : null,
          onCollapseAll: node.children.isNotEmpty
              ? () => setState(() => _setSubtreeExpanded(node, false))
              : null,
          onDoubleTapToggle: node.children.isNotEmpty
              ? () => setState(() => _setNodeExpanded(node, !node.isExpanded))
              : null,
          computedKeyWidth: keyWidth,
        );
    }

    // Wrap with validation tooltip if errors exist
    if (directErrors.isNotEmpty && widget.theme.showInlineValidation) {
      content = Tooltip(
        richMessage: WidgetSpan(
          child: ValidationTooltip(errors: directErrors),
        ),
        child: content,
      );
    }

    // Error row highlighting — tint background for nodes with errors
    if (widget.highlightErrorRows && directErrors.isNotEmpty) {
      var hasError =
          directErrors.any((e) => e.severity == ValidationSeverity.error);
      var tintColor = hasError
          ? widget.theme.colors.errorColor.withAlpha(15)
          : widget.theme.colors.warningColor.withAlpha(15);
      content = Container(
        color: tintColor,
        child: content,
      );
    }

    return content;
  }

  /// Handle additional keyboard shortcuts beyond tree navigation.
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        // Deselect and unfocus
        _treeController.select(null);
        _focusNode.unfocus();
      case LogicalKeyboardKey.tab:
        // Move to next sibling (shift+tab for previous)
        var focused = _treeController.focusedId;
        if (focused == null) return;
        if (HardwareKeyboard.instance.isShiftPressed) {
          _treeController.focusPrevious();
        } else {
          _treeController.focusNext();
        }
      default:
        break;
    }
  }
}

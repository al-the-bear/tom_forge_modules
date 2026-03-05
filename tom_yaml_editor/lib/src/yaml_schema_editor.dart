import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import 'dart:ui' as ui;

import 'editors/editor_registry.dart';
import 'inspector/inspector_dialog.dart';
import 'inspector/inspector_layouts.dart';
import 'inspector/subtree_inspector.dart';
import 'schema/schema_walker.dart';
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
  }) : editorRegistry = editorRegistry ?? const EditorRegistry();

  @override
  State<YamlSchemaEditor> createState() => _YamlSchemaEditorState();
}

class _YamlSchemaEditorState extends State<YamlSchemaEditor> {
  late TreeController<YamlTreeData> _treeController;
  late SchemaWalker? _schemaWalker;
  final FocusNode _focusNode = FocusNode();

  /// Persisted expand/collapse state keyed by node path hash.
  /// Survives document rebuilds so user's expand state is preserved.
  final Set<String> _persistedExpanded = {};

  /// Whether we've captured the initial expansion state.
  bool _initialExpansionCaptured = false;

  /// The path currently being inspected, or null if no inspector is open.
  List<String>? _inspectedPath;

  /// Computed key label widths per parent group (auto-sizing mode).
  ///
  /// Key: parent path joined by '/', Value: pixel width for key labels.
  Map<String, double> _computedKeyWidths = {};

  bool _textInputFocused = false;

  @override
  void initState() {
    super.initState();
    _schemaWalker = widget.controller.schema != null
        ? SchemaWalker(widget.controller.schema!)
        : null;
    _treeController = TreeController<YamlTreeData>(roots: []);
    _rebuildTree();
    widget.controller.addListener(_onControllerChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
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
      _rebuildTree();
    }
  }

  @override
  void dispose() {
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
      setState(() {
        _textInputFocused = isTextFocused;
      });
    }
  }

  void _onControllerChanged() {
    _rebuildTree();
    setState(() {});
    widget.onChanged?.call(widget.controller.yamlText);
    widget.onValidationChanged?.call(widget.controller.errors);
  }

  /// Rebuild the tree from the current document, preserving expand state.
  void _rebuildTree() {
    var builder = YamlTreeNodeBuilder(
      document: widget.controller.document,
      schemaWalker: _schemaWalker,
      errors: widget.controller.errors,
    );
    var roots = builder.build();

    // Capture initial expansion from the freshly built nodes
    if (!_initialExpansionCaptured) {
      _initialExpansionCaptured = true;
      for (var node in _allNodes(roots)) {
        if (node.isExpanded) _persistedExpanded.add(node.id);
      }
    }

    // Re-apply persisted expand state
    for (var node in _allNodes(roots)) {
      node.isExpanded = _persistedExpanded.contains(node.id);
    }

    _treeController.roots = roots;
    _computeKeyWidths();
  }

  void _setNodeExpanded(TreeNode<YamlTreeData> node, bool expanded) {
    if (node.children.isEmpty) return;
    final isCurrentlyExpanded = _treeController.isExpanded(node.id);
    if (expanded == isCurrentlyExpanded) return;

    if (expanded) {
      _persistedExpanded.add(node.id);
      _treeController.expand(node.id);
    } else {
      _persistedExpanded.remove(node.id);
      _treeController.collapse(node.id);
    }
  }

  void _setSubtreeExpanded(
    TreeNode<YamlTreeData> node,
    bool expanded, {
    bool includeRoot = true,
  }) {
    final nodes = node.allDescendants.where((n) => !n.isLeaf);
    for (var n in nodes) {
      if (!includeRoot && n.id == node.id) continue;
      _setNodeExpanded(n, expanded);
    }
  }

  void _setListChildrenExpanded(TreeNode<YamlTreeData> node, bool expanded) {
    for (var child in node.children) {
      _setSubtreeExpanded(child, expanded, includeRoot: true);
    }
  }

  /// Auto-expand a node's parents when a new key is inserted.
  ///
  /// Will be wired to the add-key flow in Phase 5 subtree inspector.
  // ignore: unused_element
  void _revealNode(String id) {
    _treeController.revealNode(id);
    // Persist the revealed path
    for (var node in _allNodes(_treeController.roots)) {
      if (node.isExpanded) _persistedExpanded.add(node.id);
    }
  }

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

    var fonts = widget.theme.fonts;
    var groups = <String, double>{};

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
    }

    // Small buffer for required dot (6+4px) + breathing room.
    const badgePadding = 12.0;
    var minWidth = widget.theme.keyLabelMinWidth;
    _computedKeyWidths = groups.map(
      (k, v) => MapEntry(k, (v + badgePadding).clamp(minWidth, 400.0)),
    );
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

    var treeView = Container(
      color: theme.colors.background,
      padding: theme.editorPadding,
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

    // Build the main content (tree + optional inspector)
    Widget mainContent;
    if (_inspectedPath == null) {
      mainContent = treeView;
    } else {
      switch (widget.inspectorMode) {
        case SubtreeInspectorMode.sidePanel:
          mainContent = InspectorSidePanel(
            controller: widget.controller,
            path: _inspectedPath!,
            theme: theme,
            treeView: treeView,
            readOnly: widget.readOnly,
            onClose: _closeInspector,
          );
        case SubtreeInspectorMode.bottomSheet:
          mainContent = InspectorBottomSheet(
            controller: widget.controller,
            path: _inspectedPath!,
            theme: theme,
            treeView: treeView,
            readOnly: widget.readOnly,
            onClose: _closeInspector,
          );
        case SubtreeInspectorMode.dialog:
          // Dialog is opened via _openInspector → showInspectorDialog
          mainContent = treeView;
      }
    }

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
          isTopLevel: data.kind == YamlNodeKind.mapEntry && data.path.length == 1,
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
            onExpandListItems:
              data.isContainer && (data.yamlNode?.value is List)
                ? () => setState(() => _setListChildrenExpanded(node, true))
                : null,
            onCollapseListItems:
              data.isContainer && (data.yamlNode?.value is List)
                ? () => setState(() => _setListChildrenExpanded(node, false))
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
      var hasError = directErrors
          .any((e) => e.severity == ValidationSeverity.error);
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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart';

import 'dart:ui' as ui;

import 'editors/editor_registry.dart';
import 'inspector/inspector_dialog.dart';
import 'inspector/inspector_layouts.dart';
import 'inspector/subtree_inspector.dart';
import 'model/yaml_document_model.dart';
import 'schema/schema_marker_generator.dart';
import 'schema/schema_walker.dart';
import 'text_editor/yaml_syntax_highlighter.dart';
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

  /// Whether first-load top-level expansion has been applied to controller.
  bool _initialTopLevelExpansionApplied = false;

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

  @override
  void initState() {
    super.initState();
    _schemaWalker = widget.controller.schema != null
        ? SchemaWalker(widget.controller.schema!)
        : null;
    _textDraft = widget.controller.yamlText;
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

      // New controller = new document source; reset expansion bootstrap state.
      _persistedExpanded.clear();
      _initialExpansionCaptured = false;
      _initialTopLevelExpansionApplied = false;
      if (!_textMode) {
        _textDraft = widget.controller.yamlText;
      }

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
    if (!_textMode) {
      _textDraft = widget.controller.yamlText;
      final preview = _computeTextDiagnostics(_textDraft);
      _textParseError = preview.parseError;
      _textMarkers = preview.markers;
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
      if (locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    }
    widget.onChanged?.call(widget.controller.yamlText);
    widget.onValidationChanged?.call(widget.controller.errors);
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
      for (var root in roots) {
        if (!root.isLeaf) {
          root.isExpanded = true;
          _persistedExpanded.add(root.id);
        }
      }
      for (var node in _allNodes(roots)) {
        if (node.isExpanded) _persistedExpanded.add(node.id);
      }
    }

    // Re-apply persisted expand state
    for (var node in _allNodes(roots)) {
      node.isExpanded = _persistedExpanded.contains(node.id);
    }

    _treeController.roots = roots;

    // Hard guarantee for first render: top-level container nodes start open.
    if (!_initialTopLevelExpansionApplied) {
      _initialTopLevelExpansionApplied = true;
      for (var root in roots) {
        if (!root.isLeaf) {
          _persistedExpanded.add(root.id);
          _treeController.expand(root.id);
        }
      }
    }

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
    if (includeRoot && !node.isLeaf) {
      _setNodeExpanded(node, expanded);
    }
    for (var descendant in node.allDescendants.where((n) => !n.isLeaf)) {
      _setNodeExpanded(descendant, expanded);
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

    var treeWidget = Container(
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
          isTopLevel:
              data.kind == YamlNodeKind.mapEntry && data.path.length == 1,
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
          onExpandListItems: data.isContainer && (data.yamlNode?.value is List)
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

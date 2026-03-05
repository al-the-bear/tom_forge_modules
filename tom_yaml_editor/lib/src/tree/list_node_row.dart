import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../editors/built_in/built_in_editor_factory.dart';
import '../editors/editor_popout_shell.dart';
import '../editors/editor_registry.dart';
import '../schema/schema_walker.dart';
import '../schema/yaml_schema.dart';
import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';
import 'node_actions.dart';
import 'node_context_menu.dart';
import 'yaml_tree_node_builder.dart';

/// Renders one list item in the YAML tree.
///
/// Layout: `[index] ValueEditor | NodeActions`
///
/// For container children (nested maps/lists), shows only the index + collapse
/// toggle. For scalar values, shows the index and an inline value editor.
///
/// ```dart
/// ListNodeRow(
///   node: treeNode,
///   controller: yamlController,
///   editorRegistry: registry,
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class ListNodeRow extends StatefulWidget {
  /// The tree node to render.
  final TreeNode<YamlTreeData> node;

  /// Controller for YAML document operations.
  final YamlEditorController controller;

  /// Editor registry for convention-based editors.
  final EditorRegistry editorRegistry;

  /// Schema walker for schema context.
  final SchemaWalker? schemaWalker;

  /// Theme for styling.
  final YamlEditorTheme theme;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Callback to open the subtree inspector for this node.
  final VoidCallback? onInspect;

  /// Whether this node can be expanded/collapsed.
  final bool canExpand;

  /// Current expanded state for this node.
  final bool isExpanded;

  /// Expand this node.
  final VoidCallback? onExpand;

  /// Collapse this node.
  final VoidCallback? onCollapse;

  /// Expand this node recursively.
  final VoidCallback? onExpandAll;

  /// Collapse this node recursively.
  final VoidCallback? onCollapseAll;

  /// Toggle this node on double-click.
  final VoidCallback? onDoubleTapToggle;

  const ListNodeRow({
    super.key,
    required this.node,
    required this.controller,
    required this.editorRegistry,
    this.schemaWalker,
    this.theme = const YamlEditorTheme(),
    this.readOnly = false,
    this.onInspect,
    this.canExpand = false,
    this.isExpanded = false,
    this.onExpand,
    this.onCollapse,
    this.onExpandAll,
    this.onCollapseAll,
    this.onDoubleTapToggle,
  });

  @override
  State<ListNodeRow> createState() => _ListNodeRowState();
}

class _ListNodeRowState extends State<ListNodeRow> {
  bool _isHovered = false;

  YamlTreeData get _data => widget.node.data;

  @override
  Widget build(BuildContext context) {
    var counts = widget.controller.errorCountsAt(_data.path.cast<Object>());

    return GestureDetector(
      onDoubleTap: widget.canExpand ? widget.onDoubleTapToggle : null,
      onSecondaryTapUp: widget.readOnly
          ? null
          : (details) => _showContextMenu(context, details.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              // Index badge
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.theme.colors.hintColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _data.key,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: widget.theme.fonts.keyFontFamily,
                    fontSize: widget.theme.fonts.keyFontSize - 1,
                    color: widget.theme.colors.hintColor,
                  ),
                ),
              ),

              // Validation badge
              if (widget.theme.showInlineValidation &&
                  (counts.errors > 0 || counts.warnings > 0)) ...[
                ValidationBadge(
                  errorCount: counts.errors,
                  warningCount: counts.warnings,
                  isPropagated: _data.isContainer,
                ),
                const SizedBox(width: 6),
              ],

              // Value editor (only for scalar items)
              if (_data.isScalar)
                Expanded(child: _buildValueEditor())
              else
                Expanded(
                  child: Text(
                    _containerSummary,
                    maxLines: _previewLineCount,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: widget.theme.fonts.valueFontSize,
                      color: widget.theme.colors.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Node actions (on hover)
              YamlNodeActions(
                visible: _isHovered,
                readOnly: widget.readOnly,
                onAddItem: () => widget.controller.insertListItem(
                  _parentListPath,
                  _currentIndex + 1,
                  _defaultListItemValue(),
                ),
                addItemTooltip: 'Insert item below',
                canRemove: true,
                alwaysShowRemove: true,
                canInspect: _data.isContainer,
                onRemove: () => widget.controller.removeKey(_data.path),
                onInspect: widget.onInspect,
                theme: widget.theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The parent list path (stripping the index from this node's path).
  List<String> get _parentListPath =>
      _data.path.sublist(0, _data.path.length - 1);

  /// The index of this item in its parent list.
  int get _currentIndex => int.tryParse(_data.key) ?? 0;

  int get _previewLineCount {
    final lines = widget.theme.collapsedPreviewLines;
    return lines < 1 ? 1 : lines;
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    var parentPath = _parentListPath;
    var currentIndex = _currentIndex;
    var length = widget.controller.listLength(parentPath);

    var action = await showListContextMenu(
      context: context,
      position: globalPosition,
      theme: widget.theme,
      currentIndex: currentIndex,
      listLength: length,
      canExpand: widget.canExpand,
      isExpanded: widget.isExpanded,
      canExpandAll: widget.canExpand,
      canCollapseAll: widget.canExpand,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case ListContextAction.moveUp:
        widget.controller.moveListItem(
          parentPath,
          currentIndex,
          currentIndex - 1,
        );
        return;
      case ListContextAction.moveDown:
        widget.controller.moveListItem(
          parentPath,
          currentIndex,
          currentIndex + 1,
        );
        return;
      case ListContextAction.moveToTop:
        widget.controller.moveListItem(parentPath, currentIndex, 0);
        return;
      case ListContextAction.moveToBottom:
        widget.controller.moveListItem(parentPath, currentIndex, length - 1);
        return;
      case ListContextAction.insertAbove:
        widget.controller.insertListItem(
          parentPath,
          currentIndex,
          _defaultListItemValue(),
        );
        return;
      case ListContextAction.insertBelow:
        widget.controller.insertListItem(
          parentPath,
          currentIndex + 1,
          _defaultListItemValue(),
        );
        return;
      case ListContextAction.duplicate:
        var value = _data.value;
        widget.controller.insertListItem(parentPath, currentIndex + 1, value);
        return;
      case ListContextAction.remove:
        widget.controller.removeKey(_data.path);
        return;
      case ListContextAction.expand:
        widget.onExpand?.call();
        return;
      case ListContextAction.collapse:
        widget.onCollapse?.call();
        return;
      case ListContextAction.expandAll:
        widget.onExpandAll?.call();
        return;
      case ListContextAction.collapseAll:
        widget.onCollapseAll?.call();
        return;
    }
  }

  /// Produce a reasonable default for a new list item based on schema.
  Object? _defaultListItemValue() {
    // Walk up to parent's items schema
    var parentPath = _parentListPath;
    var parentSchema = widget.schemaWalker?.nodeAt(parentPath);
    var itemSchema = parentSchema?.items;
    if (itemSchema != null) {
      if (itemSchema.defaultValue != null) return itemSchema.defaultValue;
      switch (itemSchema.type) {
        case SchemaType.string:
          return '';
        case SchemaType.integer:
          return 0;
        case SchemaType.number:
          return 0.0;
        case SchemaType.boolean:
          return false;
        case SchemaType.object:
          return <String, Object>{};
        case SchemaType.array:
          return <Object>[];
      }
    }
    return '';
  }

  Widget _buildValueEditor() {
    // Check for custom editor from registry
    var parentPath = _data.path.length > 1
        ? _data.path.sublist(0, _data.path.length - 1)
        : <String>[];
    var parentKey = parentPath.isNotEmpty ? parentPath.last : '';
    var schemaEditorType = widget.schemaWalker?.editorTypeForKey(parentPath);
    var resolved = widget.editorRegistry.resolve(
      parentKey,
      parentPath,
      schemaEditorType: schemaEditorType,
    );

    if (resolved != null) {
      var editor = resolved.factory(
        key: parentKey,
        value: _data.value,
        onChanged: widget.readOnly
            ? (_) {}
            : (v) => widget.controller.setValue(_data.path, v),
        theme: widget.theme,
        readOnly: widget.readOnly,
      );

      if (resolved.supportsPopout) {
        return EditorPopoutShell(
          theme: widget.theme,
          title: resolved.popoutTitle ?? resolved.label,
          embeddedEditor: editor,
          popoutBuilder: (_) => Padding(
            padding: const EdgeInsets.all(8),
            child: (resolved.popoutFactory ?? resolved.factory)(
              key: parentKey,
              value: _data.value,
              onChanged: widget.readOnly
                  ? (_) {}
                  : (v) => widget.controller.setValue(_data.path, v),
              theme: widget.theme,
              readOnly: widget.readOnly,
            ),
          ),
        );
      }

      return editor;
    }

    // Fall back to built-in editor
    return BuiltInEditorFactory.build(
      value: _data.value,
      schemaNode: _data.schemaNode,
      onChanged: widget.readOnly
          ? null
          : (v) => widget.controller.setValue(_data.path, v),
      theme: widget.theme,
      readOnly: widget.readOnly,
    );
  }

  String get _containerSummary {
    final value = _data.yamlNode?.value;
    final isCollapsed = widget.canExpand && !widget.isExpanded;
    if (!isCollapsed) return _countSummary(value);

    final maxLines = widget.theme.collapsedPreviewLines;
    if (maxLines <= 0) return _countSummary(value);

    final lines = <String>[];
    _collectPreviewLines(value, lines, maxLines);
    if (lines.isEmpty) return _countSummary(value);
    return lines.join('\n');
  }

  String _countSummary(Object? value) {
    if (value is Map) return '{${value.length} keys}';
    if (value is List) return '[${value.length} items]';
    return '';
  }

  void _collectPreviewLines(Object? value, List<String> out, int maxLines) {
    if (out.length >= maxLines) return;

    if (value is Map) {
      if (value.isEmpty) {
        out.add('{}');
        return;
      }
      for (final entry in value.entries) {
        if (out.length >= maxLines) break;
        final key = entry.key.toString();
        final child = entry.value;
        if (child is Map) {
          out.add('$key: {${child.length} keys}');
        } else if (child is List) {
          out.add('$key: [${child.length} items]');
        } else {
          out.add('$key: ${_scalarPreview(child)}');
        }
      }
      return;
    }

    if (value is List) {
      if (value.isEmpty) {
        out.add('[]');
        return;
      }
      for (var index = 0; index < value.length && out.length < maxLines; index++) {
        final child = value[index];
        if (child is Map) {
          out.add('- {${child.length} keys}');
        } else if (child is List) {
          out.add('- [${child.length} items]');
        } else {
          out.add('- ${_scalarPreview(child)}');
        }
      }
      return;
    }

    out.add(_scalarPreview(value));
  }

  String _scalarPreview(Object? value) {
    if (value == null) return 'null';
    if (value is String) return value;
    return value.toString();
  }
}

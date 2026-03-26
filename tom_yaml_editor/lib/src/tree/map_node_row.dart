// ignore_for_file: use_build_context_synchronously
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart' show YamlList;

import '../editors/built_in/built_in_editor_factory.dart';
import '../editors/editor_popout_shell.dart';
import '../editors/editor_registry.dart';
import '../schema/schema_walker.dart';
import '../schema/yaml_schema.dart';
import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';
import 'editor_trail.dart';
import 'key_label.dart';
import 'node_actions.dart';
import 'node_context_menu.dart';
import 'yaml_tree_node_builder.dart';

/// Payload carried by a map-key drag operation.
class _MapDragPayload {
  final List<String> parentMapPath;
  final int fromIndex;
  final String key;

  const _MapDragPayload({
    required this.parentMapPath,
    required this.fromIndex,
    required this.key,
  });
}

/// Renders one map entry in the YAML tree.
///
/// Layout: `KeyLabel : ValueEditor | NodeActions`
///
/// For container children (nested maps/lists), shows only the key + collapse
/// toggle (the children are rendered by the tree view). For scalar values,
/// shows the key and an inline value editor.
///
/// ```dart
/// MapNodeRow(
///   node: treeNode,
///   controller: yamlController,
///   editorRegistry: registry,
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class MapNodeRow extends StatefulWidget {
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

  /// Computed key label width for alignment.
  ///
  /// When non-null, overrides [YamlEditorTheme.keyLabelWidth].
  /// Typically set by the parent editor after measuring the longest key in
  /// this node's sibling group.
  final double? computedKeyWidth;

  /// Whether this row represents the synthetic/root node.
  final bool isRoot;

  /// Whether this row is a direct top-level map entry.
  final bool isTopLevel;

  /// Optional integration actions to include in the context menu.
  final List<ForgeAction>? integrationActions;

  const MapNodeRow({
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
    this.computedKeyWidth,
    this.isRoot = false,
    this.isTopLevel = false,
    this.integrationActions,
  });

  @override
  State<MapNodeRow> createState() => _MapNodeRowState();
}

class _MapNodeRowState extends State<MapNodeRow> {
  bool _isHovered = false;

  /// True  = drop indicator above the row (insert before this key's index).
  bool _dropIsAbove = true;

  YamlTreeData get _data => widget.node.data;

  /// Parent path (strips the key from the full path).
  List<String> get _parentPath =>
      _data.path.length > 1 ? _data.path.sublist(0, _data.path.length - 1) : [];

  @override
  Widget build(BuildContext context) {
    var counts = widget.controller.errorCountsAt(_data.path.cast<Object>());
    var effectiveKeyWidth =
        widget.theme.keyLabelWidth ?? widget.computedKeyWidth ?? 120.0;
    var useFlexibleKeyLabel = widget.isRoot || widget.isTopLevel;

    // Map key reorder support (skip for root / top-level).
    final canReorder = !widget.readOnly && !widget.isRoot && _parentPath.isNotEmpty;
    final keyIndex = canReorder ? widget.controller.mapKeyIndex(_data.path) : -1;
    final keyCount = canReorder ? widget.controller.mapKeyCount(_data.path) : 0;
    final canMoveUp = canReorder && keyIndex > 0;
    final canMoveDown = canReorder && keyIndex >= 0 && keyIndex < keyCount - 1;

    // Drag handle (only the icon is Draggable — keeps row taps instant)
    Widget? dragHandle;
    if (canReorder && keyIndex >= 0) {
      final payload = _MapDragPayload(
        parentMapPath: _parentPath,
        fromIndex: keyIndex,
        key: _data.key,
      );
      final feedback = Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.theme.colors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _data.key,
            style: TextStyle(
              fontFamily: widget.theme.fonts.keyFontFamily,
              fontSize: widget.theme.fonts.keyFontSize,
              color: widget.theme.colors.keyColor,
            ),
          ),
        ),
      );
      dragHandle = Draggable<_MapDragPayload>(
        data: payload,
        feedback: feedback,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.drag_indicator,
              size: 14,
              color: _isHovered
                  ? widget.theme.colors.hintColor
                  : Colors.transparent,
            ),
          ),
        ),
      );
    }

    final rowContent = GestureDetector(
      onDoubleTap: widget.canExpand ? widget.onDoubleTapToggle : null,
      onSecondaryTapUp: widget.readOnly
          ? null
          : (details) => _showContextMenu(
                context,
                details.globalPosition,
                canMoveUp: canMoveUp,
                canMoveDown: canMoveDown,
                keyIndex: keyIndex,
              ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag handle (Draggable only wraps the icon)
              if (dragHandle != null) dragHandle,

              if (_data.isContainer) ...[
                Icon(
                  (_data.yamlNode?.value is List)
                      ? Icons.data_array
                      : Icons.data_object,
                  size: 14,
                  color: widget.theme.colors.hintColor,
                ),
                const SizedBox(width: 6),
              ],

              // Key label — width adapts to longest key in sibling group
              if (useFlexibleKeyLabel)
                Flexible(
                  fit: FlexFit.loose,
                  child: KeyLabel(
                    keyName: _data.key,
                    isRequired: _data.isRequired,
                    errorCount: counts.errors,
                    warningCount: counts.warnings,
                    isPropagated: _data.isContainer,
                    theme: widget.theme,
                    ellipsize: false,
                  ),
                )
              else
                SizedBox(
                  width: effectiveKeyWidth,
                  child: KeyLabel(
                    keyName: _data.key,
                    isRequired: _data.isRequired,
                    errorCount: counts.errors,
                    warningCount: counts.warnings,
                    isPropagated: _data.isContainer,
                    theme: widget.theme,
                  ),
                ),

              const SizedBox(width: 4),

              // Value editor (only for scalar values)
              if (_data.isScalar)
                Expanded(child: _buildValueEditor())
              else
                Expanded(
                  child: Text(
                    _containerSummary,
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
                suggestedKeys: _data.isContainer
                    ? widget.controller.suggestedKeys(_data.path)
                    : [],
                // Pass the container's own schema so the + button dialog
                // can show schema-based key suggestions.
                parentSchemaNode:
                    _data.isContainer ? _data.schemaNode : null,
                onAddItem:
                    _data.isContainer && (_data.yamlNode?.value is List)
                        ? () => widget.controller.appendListItem(
                              _data.path,
                              _defaultListItemValue(),
                            )
                        : null,
                addItemTooltip: 'Add list item',
                canRemove: !_data.isRequired,
                alwaysShowRemove: true,
                canInspect: _data.isContainer,
                // Only show Add Key button if NOT a list (lists use Add Item).
                onAdd: _data.yamlNode?.value is! List
                    ? (key) => widget.controller.insertKey(
                          _data.path,
                          key,
                          _defaultValueFor(key),
                        )
                    : null,
                onAddWithType: _data.yamlNode?.value is! List
                    ? (key, value) => widget.controller.insertKey(
                          _data.path,
                          key,
                          value,
                        )
                    : null,
                onRemove: () => widget.controller.removeKey(_data.path),
                onInspect: widget.onInspect,
                theme: widget.theme,
              ),
            ],
          ),
        ),
      ),
    );

    // No DnD wrapper needed for read-only or root/top-level rows.
    if (!canReorder || keyIndex < 0) return rowContent;

    return DragTarget<_MapDragPayload>(
      onWillAcceptWithDetails: (details) {
        final d = details.data;
        return listEquals(d.parentMapPath, _parentPath) &&
            d.fromIndex != keyIndex;
      },
      onMove: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        final isAbove = local.dy < box.size.height / 2;
        if (_dropIsAbove != isAbove) setState(() => _dropIsAbove = isAbove);
      },
      onLeave: (_) {},
      onAcceptWithDetails: (details) {
        final d = details.data;
        final targetIndex = _dropIsAbove ? keyIndex : keyIndex + 1;
        widget.controller.moveMapKey(_parentPath, d.fromIndex, targetIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isCandidate = candidateData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCandidate && _dropIsAbove)
              _MapDropIndicatorLine(theme: widget.theme),
            rowContent,
            if (isCandidate && !_dropIsAbove)
              _MapDropIndicatorLine(theme: widget.theme),
          ],
        );
      },
    );
  }

  Future<void> _showContextMenu(
    BuildContext menuContext,
    Offset globalPosition, {
    bool canMoveUp = false,
    bool canMoveDown = false,
    int keyIndex = -1,
  }) async {
    trailEvent('mapRow: rightClick path=${_data.path}');
    // Capture navigator context BEFORE any async - it survives widget unmount
    final navigator = Navigator.of(menuContext);
    var suggested = widget.controller.suggestedKeys(
      _data.path.length > 1
          ? _data.path.sublist(0, _data.path.length - 1)
          : _data.path,
    );

    var action = await showMapContextMenu(
      context: menuContext,
      position: globalPosition,
      theme: widget.theme,
      suggestedKeys: suggested,
      integrationActions: widget.integrationActions,
      canRemove: !_data.isRequired,
      canInspect: _data.isContainer,
      canExpand: widget.canExpand,
      isExpanded: widget.isExpanded,
      canExpandAll: widget.canExpand,
      canCollapseAll: widget.canExpand,
      // Show 'Add key' for any row that is NOT a list value.  Scalar values
      // are transparently upgraded to maps by the controller's insertKey.
      // List values must not be clobbered, so we exclude them.
      canAddKey: _data.yamlNode is! YamlList,
      canMoveUp: canMoveUp,
      canMoveDown: canMoveDown,
    );
    if (action == null) return;
    trailEvent('mapRow: action=$action path=${_data.path}');

    try {
      switch (action) {
        case MapContextAction.moveUp:
          if (keyIndex > 0) {
            widget.controller.moveMapKey(_parentPath, keyIndex, keyIndex - 1);
          }
          return;
        case MapContextAction.moveDown:
          widget.controller.moveMapKey(_parentPath, keyIndex, keyIndex + 1);
          return;
        case MapContextAction.insertKeyAbove:
        case MapContextAction.insertKeyBelow:
          // Capture references before any async operation - widget may unmount
          final insertController = widget.controller;
          final insertPath = _data.path;
          final insertParentPath = _parentPath;
          final insertAbove = action == MapContextAction.insertKeyAbove;
          trailEvent('mapRow: opening insert-adjacent dialog');
          final addResult = await showAddKeyDialog(
            navigator.context,
            parentSchema: insertController.schemaNodeAt(insertParentPath),
            allowedKeys: insertController.suggestedKeys(insertParentPath),
          );
          trailEvent('mapRow: insert-adjacent result=${addResult?.key}');
          if (addResult == null) return;
          insertController.insertKeyAdjacent(
            insertPath,
            addResult.key,
            addResult.value,
            above: insertAbove,
          );
          return;
        case MapContextAction.removeKey:
          widget.controller.removeKey(_data.path);
          return;
        case MapContextAction.inspectAsYaml:
          widget.onInspect?.call();
          return;
        case MapContextAction.expand:
          widget.onExpand?.call();
          return;
        case MapContextAction.collapse:
          widget.onCollapse?.call();
          return;
        case MapContextAction.expandAll:
          widget.onExpandAll?.call();
          return;
        case MapContextAction.collapseAll:
          widget.onCollapseAll?.call();
          return;
        case MapContextAction.addKey:
          // Capture references before any async operation - widget may unmount
          final addKeyController = widget.controller;
          final addKeyPath = _data.path;
          final addKeySchemaNode = _data.schemaNode;
          trailEvent(
            'mapRow: addKey opening dialog path=$addKeyPath '
            'allowed=${addKeyController.suggestedKeys(addKeyPath)}',
          );
          final addResult = await showAddKeyDialog(
            navigator.context,
            parentSchema: addKeySchemaNode,
            allowedKeys: addKeyController.suggestedKeys(addKeyPath),
          );
          trailEvent('mapRow: addKey result=${addResult?.key}');
          if (addResult == null) return;
          addKeyController.insertKey(addKeyPath, addResult.key, addResult.value);
          return;
      }
    } catch (e, st) {
      trailEvent('mapRow: ERROR in $action – $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'yaml_schema_editor',
        context: ErrorDescription('map context menu action: $action'),
      ));
    }
  }

  Widget _buildValueEditor() {
    // 1. Check EditorRegistry for custom/suffix-based editor
    var schemaEditorType = widget.schemaWalker?.editorTypeForKey(_data.path);
    var resolved = widget.editorRegistry.resolve(
      _data.key,
      _data.path,
      schemaEditorType: schemaEditorType,
    );

    if (resolved != null) {
      var editor = resolved.factory(
        key: _data.key,
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
              key: _data.key,
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

    // 2. Fall back to built-in editor
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
    var value = _data.yamlNode?.value;
    if (value is Map) return '{${value.length} keys}';
    if (value is List) return '[${value.length} items]';
    return '';
  }

  Object? _defaultValueFor(String key) {
    var childSchema = _data.schemaNode?.properties[key];
    if (childSchema?.defaultValue != null) return childSchema!.defaultValue;
    switch (childSchema?.type) {
      case null:
        return '';
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

  Object? _defaultListItemValue() {
    final itemSchema = _data.schemaNode?.items;
    if (itemSchema?.defaultValue != null) return itemSchema!.defaultValue;
    switch (itemSchema?.type) {
      case null:
        return '';
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
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Drop indicator line shown during drag-and-drop reordering of map keys.
class _MapDropIndicatorLine extends StatelessWidget {
  final YamlEditorTheme theme;
  const _MapDropIndicatorLine({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: theme.colors.selectionColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

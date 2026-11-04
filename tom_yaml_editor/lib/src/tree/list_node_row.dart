// ignore_for_file: use_build_context_synchronously
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../editors/built_in/built_in_editor_factory.dart';
import '../editors/editor_popout_shell.dart';
import '../editors/editor_registry.dart';
import '../schema/schema_walker.dart';
import '../schema/yaml_schema.dart';
import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';
import 'editor_trail.dart';
import 'node_actions.dart';
import 'node_context_menu.dart';
import 'yaml_tree_node_builder.dart';

/// Payload carried by a list-item drag operation.
class _ListDragPayload {
  final List<String> parentListPath;
  final int fromIndex;

  const _ListDragPayload({
    required this.parentListPath,
    required this.fromIndex,
  });
}

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

  /// Optional integration actions to include in the context menu.
  final List<ForgeAction>? integrationActions;

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
    this.integrationActions,
  });

  @override
  State<ListNodeRow> createState() => _ListNodeRowState();
}

class _ListNodeRowState extends State<ListNodeRow> {
  bool _isHovered = false;

  /// True  = drop-indicator shows above the row (insert before this index).
  /// False = drop-indicator shows below the row (insert after this index).
  bool _dropIsAbove = true;

  YamlTreeData get _data => widget.node.data;

  @override
  Widget build(BuildContext context) {
    var counts = widget.controller.errorCountsAt(_data.path.cast<Object>());
    final listLen = widget.controller.listLength(_parentListPath);
    final canMoveUp = _currentIndex > 0;
    final canMoveDown = _currentIndex < listLen - 1;

    // ---------------------------------------------------------------------------
    // Drag handle — the ONLY widget wrapped in Draggable.
    // Keeping the Draggable off the row's tap/click area prevents the gesture
    // arena from delaying all interactions with a long-press timeout.
    // ---------------------------------------------------------------------------
    Widget? dragHandle;
    if (!widget.readOnly) {
      final payload = _ListDragPayload(
        parentListPath: _parentListPath,
        fromIndex: _currentIndex,
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
            '[${_data.key}]',
            style: TextStyle(
              fontFamily: widget.theme.fonts.keyFontFamily,
              fontSize: widget.theme.fonts.keyFontSize,
              color: widget.theme.colors.hintColor,
            ),
          ),
        ),
      );

      dragHandle = Draggable<_ListDragPayload>(
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
          : (details) => _showContextMenu(context, details.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              // Drag handle (only the icon is draggable — keeps row taps instant)
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

              // Node actions (visible on hover)
              YamlNodeActions(
                visible: _isHovered,
                readOnly: widget.readOnly,
                // (d) "Add Key" button when this list item IS a map.
                onAdd: _data.isContainer && _data.yamlNode?.value is Map
                    ? (key) => widget.controller
                        .insertKey(_data.path, key, _defaultValueForKey(key))
                    : null,
                onAddWithType: _data.isContainer && _data.yamlNode?.value is Map
                    ? (key, value) =>
                        widget.controller.insertKey(_data.path, key, value)
                    : null,
                suggestedKeys: _data.isContainer && _data.yamlNode?.value is Map
                    ? widget.controller.suggestedKeys(_data.path)
                    : [],
                parentSchemaNode:
                    _data.isContainer && _data.yamlNode?.value is Map
                        ? _data.schemaNode
                        : null,
                // Insert-below button for the parent list.
                onAddItemWithType: (value) => widget.controller.insertListItem(
                  _parentListPath,
                  _currentIndex + 1,
                  value,
                ),
                itemsSchemaNode:
                    widget.schemaWalker?.nodeAt(_parentListPath)?.items,
                addItemTooltip: 'Insert item below',
                canMoveUp: canMoveUp,
                canMoveDown: canMoveDown,
                onMoveUp: canMoveUp
                    ? () => widget.controller.moveListItem(
                        _parentListPath, _currentIndex, _currentIndex - 1)
                    : null,
                onMoveDown: canMoveDown
                    ? () => widget.controller.moveListItem(
                        _parentListPath, _currentIndex, _currentIndex + 2)
                    : null,
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

    if (widget.readOnly) return rowContent;

    return DragTarget<_ListDragPayload>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        return listEquals(data.parentListPath, _parentListPath) &&
            data.fromIndex != _currentIndex;
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
        final data = details.data;
        final targetIndex = _dropIsAbove ? _currentIndex : _currentIndex + 1;
        widget.controller
            .moveListItem(_parentListPath, data.fromIndex, targetIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isCandidate = candidateData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCandidate && _dropIsAbove)
              _DropIndicatorLine(theme: widget.theme),
            rowContent,
            if (isCandidate && !_dropIsAbove)
              _DropIndicatorLine(theme: widget.theme),
          ],
        );
      },
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
    BuildContext menuContext,
    Offset globalPosition,
  ) async {
    trailEvent('listRow: rightClick path=${_data.path}');
    // Capture navigator context BEFORE any async - it survives widget unmount
    final navigator = Navigator.of(menuContext);
    final parentPath = _parentListPath;
    final currentIndex = _currentIndex;
    final length = widget.controller.listLength(parentPath);
    final isMapContainer = _data.isContainer && _data.yamlNode?.value is Map;

    final action = await showListContextMenu(
      context: menuContext,
      position: globalPosition,
      theme: widget.theme,
      currentIndex: currentIndex,
      listLength: length,
      integrationActions: widget.integrationActions,
      canExpand: widget.canExpand,
      isExpanded: widget.isExpanded,
      canExpandAll: widget.canExpand,
      canCollapseAll: widget.canExpand,
      isContainer: isMapContainer,
    );
    if (action == null) return;
    trailEvent('listRow: action=$action path=${_data.path}');

    try {
      switch (action) {
        case ListContextAction.moveUp:
          widget.controller
              .moveListItem(parentPath, currentIndex, currentIndex - 1);
          return;
        case ListContextAction.moveDown:
          widget.controller
              .moveListItem(parentPath, currentIndex, currentIndex + 1);
          return;
        case ListContextAction.moveToTop:
          trailEvent('listRow: moveToTop idx=$currentIndex -> 0');
          widget.controller.moveListItem(parentPath, currentIndex, 0);
          return;
        case ListContextAction.moveToBottom:
          trailEvent('listRow: moveToBottom idx=$currentIndex -> $length');
          widget.controller.moveListItem(parentPath, currentIndex, length);
          return;
        case ListContextAction.duplicate:
          trailEvent(
              'listRow: duplicate idx=$currentIndex val=${trailTruncate(_data.value)}');
          widget.controller
              .insertListItem(parentPath, currentIndex + 1, _data.value);
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
        // ---------------------------------------------------------------------
        // Async operations — capture references before any await
        // ---------------------------------------------------------------------
        case ListContextAction.insertAbove:
          trailEvent('listRow: insertAbove ENTERED');
          // Capture BEFORE any async call - widget may unmount when tree rebuilds
          final controllerAbove = widget.controller;
          final pathAbove = parentPath;
          final indexAbove = currentIndex;
          trailEvent('listRow: insertAbove picking value');
          final pickedAbove =
              await _pickInsertValue(navigator.context, globalPosition);
          trailEvent(
              'listRow: insertAbove result=${trailTruncate(pickedAbove?.value)}');
          if (pickedAbove == null) return;
          controllerAbove.insertListItem(
              pathAbove, indexAbove, pickedAbove.value);
          return;
        case ListContextAction.insertBelow:
          trailEvent('listRow: insertBelow ENTERED');
          // Capture BEFORE any async call - widget may unmount when tree rebuilds
          final controllerBelow = widget.controller;
          final pathBelow = parentPath;
          final indexBelow = currentIndex + 1;
          trailEvent('listRow: insertBelow picking value');
          final pickedBelow =
              await _pickInsertValue(navigator.context, globalPosition);
          trailEvent(
              'listRow: insertBelow result=${trailTruncate(pickedBelow?.value)}');
          if (pickedBelow == null) return;
          controllerBelow.insertListItem(
              pathBelow, indexBelow, pickedBelow.value);
          return;
        case ListContextAction.addKey:
          // Capture references before any async operation - widget may unmount
          final addKeyController = widget.controller;
          final addKeyPath = _data.path;
          final addKeySchemaNode = _data.schemaNode;
          trailEvent(
              'listRow: addKey opening dialog allowed=${addKeyController.suggestedKeys(addKeyPath)}');
          final addResult = await showAddKeyDialog(
            navigator.context,
            parentSchema: addKeySchemaNode,
            allowedKeys: addKeyController.suggestedKeys(addKeyPath),
          );
          trailEvent('listRow: addKey result=${addResult?.key}');
          if (addResult == null) return;
          addKeyController.insertKey(
              addKeyPath, addResult.key, addResult.value);
          return;
      }
    } catch (e, st) {
      trailEvent('listRow: ERROR in $action – $e');
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'yaml_schema_editor',
        context: ErrorDescription('list context menu action: $action'),
      ));
    }
  }

  /// Default value for a new key added to a map-typed list item.
  Object? _defaultValueForKey(String key) {
    final mapSchema = _data.schemaNode;
    if (mapSchema == null) return '';
    final childSchema = mapSchema.properties[key];
    if (childSchema?.defaultValue != null) return childSchema!.defaultValue;
    return switch (childSchema?.type) {
      SchemaType.string => '',
      SchemaType.integer => 0,
      SchemaType.number => 0.0,
      SchemaType.boolean => false,
      SchemaType.object => <String, Object>{},
      SchemaType.array => <Object>[],
      null => '',
    };
  }

  /// Choose the value for a new list item.
  ///
  /// If the schema mandates a specific type for items in this list, that
  /// default is returned immediately without showing a dialog.  Otherwise a
  /// type-picker popup is shown at [menuOffset] so the user can choose.
  ///
  /// Returns `null` when the user dismisses the picker without selecting.
  Future<({Object? value})?> _pickInsertValue(
    BuildContext context,
    Offset menuOffset,
  ) async {
    trailEvent('_pickInsertValue: ENTER');
    // Schema-mandated type → use default directly, no dialog needed.
    final parentSchema = widget.schemaWalker?.nodeAt(_parentListPath);
    final itemSchema = parentSchema?.items;
    trailEvent('_pickInsertValue: itemSchema=${itemSchema?.type}');
    if (itemSchema != null) {
      final val = _defaultListItemValue();
      trailEvent('_pickInsertValue: using default val=$val');
      return (value: val);
    }

    // No schema constraint → ask the user what type to insert.
    trailEvent('_pickInsertValue: checking mounted=${context.mounted}');
    if (!context.mounted) return null;
    final type = await showMenu<AddKeyType>(
      context: context,
      position: RelativeRect.fromLTRB(
        menuOffset.dx,
        menuOffset.dy,
        menuOffset.dx + 1,
        menuOffset.dy + 1,
      ),
      items: AddKeyType.values
          .map(
            (t) => PopupMenuItem<AddKeyType>(
              value: t,
              height: 32,
              child: Text(t.label, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
    );
    if (type == null) return null; // user dismissed
    return (value: type.toValue());
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
      // A host-registered editor writes through setValue into the document's
      // history; its own text fields keep none.
      editor = ForgeEditorOwnsUndo(child: editor);

      if (resolved.supportsPopout) {
        return EditorPopoutShell(
          theme: widget.theme,
          title: resolved.popoutTitle ?? resolved.label,
          embeddedEditor: editor,
          popoutBuilder: (_) => Padding(
            padding: const EdgeInsets.all(8),
            // The popout route is outside the editor's key map: the
            // platform's undo keys reach the document's history here.
            child: ForgeEditorOwnsUndo(
              onUndo: widget.controller.undo,
              onRedo: widget.controller.redo,
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

    final tokens = _collectPreviewTokens(value);
    if (tokens.isEmpty) return _countSummary(value);
    return tokens.join(', ');
  }

  String _countSummary(Object? value) {
    if (value is Map) return '{${value.length} keys}';
    if (value is List) return '[${value.length} items]';
    return '';
  }

  List<String> _collectPreviewTokens(Object? value) {
    final out = <String>[];
    if (value is Map) {
      if (value.isEmpty) {
        return ['{}'];
      }
      for (final entry in value.entries) {
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
      return out;
    }

    if (value is List) {
      if (value.isEmpty) {
        return ['[]'];
      }
      for (var index = 0; index < value.length; index++) {
        final child = value[index];
        if (child is Map) {
          out.add('- {${child.length} keys}');
        } else if (child is List) {
          out.add('- [${child.length} items]');
        } else {
          out.add('- ${_scalarPreview(child)}');
        }
      }
      return out;
    }

    return [_scalarPreview(value)];
  }

  String _scalarPreview(Object? value) {
    if (value == null) return 'null';
    if (value is String) return value;
    return value.toString();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A thin colored horizontal line shown above or below a list item during
/// a drag-and-drop operation to indicate the drop position.
class _DropIndicatorLine extends StatelessWidget {
  final YamlEditorTheme theme;

  const _DropIndicatorLine({required this.theme});

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

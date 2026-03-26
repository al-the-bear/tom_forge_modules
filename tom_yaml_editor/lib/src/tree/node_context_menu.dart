import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../yaml_editor_theme.dart';
import 'editor_trail.dart';

/// Context menu actions available for map entry nodes.
enum MapContextAction {
  /// Expand this node.
  expand,

  /// Collapse this node.
  collapse,

  /// Expand this subtree recursively.
  expandAll,

  /// Collapse this subtree recursively.
  collapseAll,

  /// Move this key one position up within its parent map.
  moveUp,

  /// Move this key one position down within its parent map.
  moveDown,

  /// Insert a new key above the current key.
  insertKeyAbove,

  /// Insert a new key below the current key.
  insertKeyBelow,

  /// Remove this key.
  removeKey,

  /// Edit value as raw YAML.
  inspectAsYaml,

  /// Add a new key to this map value (the value at this entry is itself a map).
  addKey,
}

/// Context menu actions available for list item nodes.
enum ListContextAction {
  /// Expand this node.
  expand,

  /// Collapse this node.
  collapse,

  /// Expand this subtree recursively.
  expandAll,

  /// Collapse this subtree recursively.
  collapseAll,

  /// Move item up one position.
  moveUp,

  /// Move item down one position.
  moveDown,

  /// Move item to the top of the list.
  moveToTop,

  /// Move item to the bottom of the list.
  moveToBottom,

  /// Insert a new item above this one.
  insertAbove,

  /// Insert a new item below this one.
  insertBelow,

  /// Duplicate this item.
  duplicate,

  /// Remove this item.
  remove,

  /// Add a key to this container item (when the item is a map).
  addKey,
}

/// Shows a context menu for a map entry node.
///
/// Returns the selected [MapContextAction], or null if dismissed.
/// Integration actions (from [ForgeEditorIntegration.supportedActions])
/// are executed directly via `onTap` and return null.
Future<MapContextAction?> showMapContextMenu({
  required BuildContext context,
  required Offset position,
  required YamlEditorTheme theme,
  required List<String> suggestedKeys,
  List<ForgeAction>? integrationActions,
  bool canRemove = true,
  bool canInspect = false,
  bool canExpand = false,
  bool isExpanded = false,
  bool canExpandAll = false,
  bool canCollapseAll = false,
  bool canMoveUp = false,
  bool canMoveDown = false,
  bool canAddKey = false,
  bool isReadOnly = false,
}) async {
  if (isReadOnly) return null;
  trailEvent('mapContextMenu: open canAddKey=$canAddKey');

  var items = <PopupMenuEntry<MapContextAction>>[];

  if (canExpand) {
    items.add(
      _menuItem(
        value: isExpanded ? MapContextAction.collapse : MapContextAction.expand,
        icon: isExpanded ? Icons.unfold_less : Icons.unfold_more,
        label: isExpanded ? 'Collapse' : 'Expand',
        color: theme.colors.keyColor,
      ),
    );
  }

  if (canExpandAll || canCollapseAll) {
    items.add(
      _menuItem(
        value: MapContextAction.expandAll,
        icon: Icons.unfold_more,
        label: 'Expand all',
        color: theme.colors.keyColor,
        enabled: canExpandAll,
      ),
    );
    items.add(
      _menuItem(
        value: MapContextAction.collapseAll,
        icon: Icons.unfold_less,
        label: 'Collapse all',
        color: theme.colors.keyColor,
        enabled: canCollapseAll,
      ),
    );
  }

  if (items.isNotEmpty) {
    items.add(const PopupMenuDivider(height: 4));
  }

  // Reorder actions (only when the parent map has more than one key)
  if (canMoveUp || canMoveDown) {
    items.addAll([
      _menuItem(
        value: MapContextAction.moveUp,
        icon: Icons.arrow_upward,
        label: 'Move up',
        color: theme.colors.keyColor,
        enabled: canMoveUp,
      ),
      _menuItem(
        value: MapContextAction.moveDown,
        icon: Icons.arrow_downward,
        label: 'Move down',
        color: theme.colors.keyColor,
        enabled: canMoveDown,
      ),
      const PopupMenuDivider(height: 4),
    ]);
  }

  items.addAll([
    _menuItem(
      value: MapContextAction.insertKeyAbove,
      icon: Icons.arrow_upward,
      label: 'Insert key above',
      color: theme.structureColors.addButton,
    ),
    _menuItem(
      value: MapContextAction.insertKeyBelow,
      icon: Icons.arrow_downward,
      label: 'Insert key below',
      color: theme.structureColors.addButton,
    ),
    const PopupMenuDivider(height: 4),
  ]);

  if (canAddKey) {
    items.addAll([
      _menuItem(
        value: MapContextAction.addKey,
        icon: Icons.add,
        label: 'Add key',
        color: theme.structureColors.addButton,
      ),
      const PopupMenuDivider(height: 4),
    ]);
  }

  if (canRemove) {
    items.add(_menuItem(
      value: MapContextAction.removeKey,
      icon: Icons.delete_outline,
      label: 'Remove',
      color: theme.structureColors.removeButton,
    ));
  }

  if (canInspect) {
    items.add(_menuItem(
      value: MapContextAction.inspectAsYaml,
      icon: Icons.code,
      label: 'Edit as YAML',
      color: theme.colors.hintColor,
    ));
  }

  // Integration actions (self-executing, return null when selected)
  final filteredActions = integrationActions
      ?.where((a) => a.showInContextMenu && a.isEnabled())
      .toList();
  if (filteredActions != null && filteredActions.isNotEmpty) {
    items.add(const PopupMenuDivider(height: 4));
    for (final action in filteredActions) {
      items.add(_integrationMenuItem<MapContextAction>(
        action: action,
        color: theme.colors.keyColor,
      ));
    }
  }

  if (items.isEmpty) return null;

  return showMenu<MapContextAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: items,
  );
}

/// Shows a context menu for a list item node.
///
/// Returns the selected [ListContextAction], or null if dismissed.
/// Integration actions (from [ForgeEditorIntegration.supportedActions])
/// are executed directly via `onTap` and return null.
Future<ListContextAction?> showListContextMenu({
  required BuildContext context,
  required Offset position,
  required YamlEditorTheme theme,
  required int currentIndex,
  required int listLength,
  List<ForgeAction>? integrationActions,
  bool canExpand = false,
  bool isExpanded = false,
  bool canExpandAll = false,
  bool canCollapseAll = false,
  bool isReadOnly = false,
  bool isContainer = false,
}) async {
  if (isReadOnly) return null;

  var isFirst = currentIndex == 0;
  var isLast = currentIndex == listLength - 1;

  var items = <PopupMenuEntry<ListContextAction>>[
    if (canExpand)
      _menuItem(
        value:
            isExpanded ? ListContextAction.collapse : ListContextAction.expand,
        icon: isExpanded ? Icons.unfold_less : Icons.unfold_more,
        label: isExpanded ? 'Collapse' : 'Expand',
        color: theme.colors.keyColor,
      ),
    if (canExpandAll || canCollapseAll)
      _menuItem(
        value: ListContextAction.expandAll,
        icon: Icons.unfold_more,
        label: 'Expand all',
        color: theme.colors.keyColor,
        enabled: canExpandAll,
      ),
    if (canExpandAll || canCollapseAll)
      _menuItem(
        value: ListContextAction.collapseAll,
        icon: Icons.unfold_less,
        label: 'Collapse all',
        color: theme.colors.keyColor,
        enabled: canCollapseAll,
      ),
    if (canExpand || canExpandAll || canCollapseAll)
      const PopupMenuDivider(height: 4),

    // Reorder actions
    _menuItem(
      value: ListContextAction.moveUp,
      icon: Icons.arrow_upward,
      label: 'Move up',
      color: theme.colors.keyColor,
      enabled: !isFirst,
    ),
    _menuItem(
      value: ListContextAction.moveDown,
      icon: Icons.arrow_downward,
      label: 'Move down',
      color: theme.colors.keyColor,
      enabled: !isLast,
    ),
    _menuItem(
      value: ListContextAction.moveToTop,
      icon: Icons.vertical_align_top,
      label: 'Move to top',
      color: theme.colors.keyColor,
      enabled: !isFirst,
    ),
    _menuItem(
      value: ListContextAction.moveToBottom,
      icon: Icons.vertical_align_bottom,
      label: 'Move to bottom',
      color: theme.colors.keyColor,
      enabled: !isLast,
    ),

    const PopupMenuDivider(height: 4),

    // Insert actions
    _menuItem(
      value: ListContextAction.insertAbove,
      icon: Icons.add,
      label: 'Insert above',
      color: theme.structureColors.addButton,
    ),
    _menuItem(
      value: ListContextAction.insertBelow,
      icon: Icons.add,
      label: 'Insert below',
      color: theme.structureColors.addButton,
    ),
    _menuItem(
      value: ListContextAction.duplicate,
      icon: Icons.copy,
      label: 'Duplicate',
      color: theme.structureColors.addButton,
    ),

    const PopupMenuDivider(height: 4),

    // Remove
    _menuItem(
      value: ListContextAction.remove,
      icon: Icons.delete_outline,
      label: 'Remove',
      color: theme.structureColors.removeButton,
    ),

    // Add key (only for container map items)
    if (isContainer) ...
      [
        const PopupMenuDivider(height: 4),
        _menuItem(
          value: ListContextAction.addKey,
          icon: Icons.add,
          label: 'Add key',
          color: theme.structureColors.addButton,
        ),
      ],
  ];

  // Integration actions (self-executing, return null when selected)
  final filteredActions = integrationActions
      ?.where((a) => a.showInContextMenu && a.isEnabled())
      .toList();
  if (filteredActions != null && filteredActions.isNotEmpty) {
    items.add(const PopupMenuDivider(height: 4));
    for (final action in filteredActions) {
      items.add(_integrationMenuItem<ListContextAction>(
        action: action,
        color: theme.colors.keyColor,
      ));
    }
  }

  return showMenu<ListContextAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: items,
  );
}

/// Helper to show a key selection sub-menu for insert operations.
Future<String?> showKeySelectionMenu({
  required BuildContext context,
  required Offset position,
  required List<String> keys,
}) async {
  if (keys.isEmpty) return null;
  if (keys.length == 1) return keys.first;

  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: keys.map((key) {
      return PopupMenuItem<String>(
        value: key,
        height: 32,
        child: Text(key, style: const TextStyle(fontSize: 12)),
      );
    }).toList(),
  );
}

PopupMenuItem<T> _menuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  Color? color,
  bool enabled = true,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: 32,
    enabled: enabled,
    child: Row(
      children: [
        Icon(icon, size: 16, color: enabled ? color : null),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? null : Colors.grey,
          ),
        ),
      ],
    ),
  );
}

/// Creates a menu item for a [ForgeAction] that self-executes on tap.
///
/// Returns `null` value so the caller's enum-based handler ignores it.
/// The action is executed via `onTap` before the menu closes.
PopupMenuItem<T> _integrationMenuItem<T>({
  required ForgeAction action,
  Color? color,
}) {
  return PopupMenuItem<T>(
    value: null as T,
    height: 32,
    onTap: () {
      trailEvent('contextMenu: integration action ${action.id}');
      action.execute({});
    },
    child: Row(
      children: [
        Icon(action.icon ?? Icons.play_arrow, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          action.label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

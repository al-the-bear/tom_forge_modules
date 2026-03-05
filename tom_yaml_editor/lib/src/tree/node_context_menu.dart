import 'package:flutter/material.dart';

import '../yaml_editor_theme.dart';

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

  /// Expand all objects/items under this list node.
  expandListItems,

  /// Collapse all objects/items under this list node.
  collapseListItems,

  /// Insert a new key above the current key.
  insertKeyAbove,

  /// Insert a new key below the current key.
  insertKeyBelow,

  /// Remove this key.
  removeKey,

  /// Edit value as raw YAML.
  inspectAsYaml,
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
}

/// Shows a context menu for a map entry node.
///
/// Returns the selected [MapContextAction], or null if dismissed.
Future<MapContextAction?> showMapContextMenu({
  required BuildContext context,
  required Offset position,
  required YamlEditorTheme theme,
  required List<String> suggestedKeys,
  bool canRemove = true,
  bool canInspect = false,
  bool canExpand = false,
  bool isExpanded = false,
  bool canExpandAll = false,
  bool canCollapseAll = false,
  bool canListItemExpandCollapse = false,
  bool isReadOnly = false,
}) async {
  if (isReadOnly) return null;

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

  if (canListItemExpandCollapse) {
    items.add(
      _menuItem(
        value: MapContextAction.expandListItems,
        icon: Icons.playlist_add_check,
        label: 'Expand all items',
        color: theme.colors.keyColor,
      ),
    );
    items.add(
      _menuItem(
        value: MapContextAction.collapseListItems,
        icon: Icons.playlist_remove,
        label: 'Collapse all items',
        color: theme.colors.keyColor,
      ),
    );
  }

  if (items.isNotEmpty) {
    items.add(const PopupMenuDivider(height: 4));
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
Future<ListContextAction?> showListContextMenu({
  required BuildContext context,
  required Offset position,
  required YamlEditorTheme theme,
  required int currentIndex,
  required int listLength,
  bool canExpand = false,
  bool isExpanded = false,
  bool canExpandAll = false,
  bool canCollapseAll = false,
  bool isReadOnly = false,
}) async {
  if (isReadOnly) return null;

  var isFirst = currentIndex == 0;
  var isLast = currentIndex == listLength - 1;

  var items = <PopupMenuEntry<ListContextAction>>[
    if (canExpand)
      _menuItem(
        value: isExpanded ? ListContextAction.collapse : ListContextAction.expand,
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
  ];

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

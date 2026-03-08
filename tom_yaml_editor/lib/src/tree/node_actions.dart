import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../yaml_editor_theme.dart';

/// Initial value type selected in the add-key / add-item dialog.
///
/// Exposed publicly so the dialog can be reused from context menus and
/// action buttons without duplicating code.
enum AddKeyType {
  string,
  boolean,
  integer,
  float,
  map,
  list,
  nullValue;

  Object? toValue() => switch (this) {
        AddKeyType.string => '',
        AddKeyType.boolean => false,
        AddKeyType.integer => 0,
        AddKeyType.float => 0.0,
        AddKeyType.map => <String, Object>{},
        AddKeyType.list => <Object>[],
        AddKeyType.nullValue => null,
      };

  String get label => switch (this) {
        AddKeyType.string => 'String  ""',
        AddKeyType.boolean => 'Bool  false',
        AddKeyType.integer => 'Int  0',
        AddKeyType.float => 'Float  0.0',
        AddKeyType.map => 'Map  {}',
        AddKeyType.list => 'List  []',
        AddKeyType.nullValue => 'Null',
      };
}

/// Shows the shared add-key dialog: asks for a key name and initial value type.
///
/// Returns `null` if the user cancels or enters an empty key name.
/// Used by both the inline action button and the right-click context menu so
/// that all "insert key" paths always go through the same dialog.
Future<({String key, AddKeyType type})?> showAddKeyDialog(
    BuildContext context) async {
  final keyController = TextEditingController();
  var selectedType = AddKeyType.string;

  final result = await showDialog<({String key, AddKeyType type})>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Key name',
                    hintText: 'new-key',
                  ),
                  onSubmitted: (value) => Navigator.of(dialogContext)
                      .pop((key: value.trim(), type: selectedType)),
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Initial value type',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AddKeyType>(
                      value: selectedType,
                      isDense: true,
                      items: AddKeyType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ))
                          .toList(),
                      onChanged: (t) =>
                          setDialogState(() => selectedType = t!),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                    (key: keyController.text.trim(), type: selectedType)),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );

  final key = result?.key.trim() ?? '';
  if (key.isEmpty) return null;
  return (key: key, type: result!.type);
}

/// Row of action buttons for a YAML tree node.
///
/// Shows add/remove/inspect buttons based on:
/// - Schema suggestions (for add button).
/// - Whether the key is optional (for remove button).
/// - Theme toggle flags (`showAddButtons`, `showRemoveButtons`).
/// - Whether the editor is read-only.
///
/// ```dart
/// YamlNodeActions(
///   suggestedKeys: ['description', 'version'],
///   canRemove: true,
///   canInspect: true,
///   onAdd: (key) => controller.insertKey(path, key, null),
///   onRemove: () => controller.removeKey(path),
///   onInspect: () => openSubtreeInspector(path),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class YamlNodeActions extends StatelessWidget {
  /// Keys that can be added (from schema suggestions).
  final List<String> suggestedKeys;

  /// Whether this node can be removed.
  final bool canRemove;

  /// Whether remove should stay visible even when [visible] is false.
  final bool alwaysShowRemove;

  /// Whether this node can be inspected as raw YAML.
  final bool canInspect;

  /// Callback when a schema-suggested key is added (key name only).
  final ValueChanged<String>? onAdd;

  /// Callback when a key is manually added with an explicit initial value
  /// type chosen by the user in the add-key dialog.
  final void Function(String key, Object? value)? onAddWithType;

  /// Callback for direct add actions (e.g. append list item).
  final VoidCallback? onAddItem;

  /// Tooltip used for [onAddItem] action.
  final String addItemTooltip;

  /// Callback when a list item is added via the type-picker popup.
  ///
  /// When provided, the add-item button shows a type-selection popup instead
  /// of calling [onAddItem] directly. The selected value (of the corresponding
  /// type) is passed as the argument.
  final ValueChanged<Object?>? onAddItemWithType;

  /// Whether this node can be moved up within its parent container.
  final bool canMoveUp;

  /// Whether this node can be moved down within its parent container.
  final bool canMoveDown;

  /// Callback to move this node one position up.
  final VoidCallback? onMoveUp;

  /// Callback to move this node one position down.
  final VoidCallback? onMoveDown;

  /// Callback when this node is removed.
  final VoidCallback? onRemove;

  /// Callback to open the subtree inspector.
  final VoidCallback? onInspect;

  /// Whether the actions are visible.
  final bool visible;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  const YamlNodeActions({
    super.key,
    this.suggestedKeys = const [],
    this.canRemove = false,
    this.alwaysShowRemove = false,
    this.canInspect = false,
    this.onAdd,
    this.onAddWithType,
    this.onAddItem,
    this.addItemTooltip = 'Add item',
    this.onAddItemWithType,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onInspect,
    this.visible = true,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  @override
  Widget build(BuildContext context) {
    if (readOnly) return const SizedBox.shrink();

    var actions = <NodeAction>[];
    NodeAction? pinnedRemoveAction;

    // Add key button (schema suggestions and/or manual key entry fallback)
    if (theme.showAddButtons && (onAdd != null || onAddWithType != null)) {
      actions.add(NodeAction(
        icon: Icons.add,
        tooltip: 'Add key',
        color: theme.structureColors.addButton,
        onPressed: () => _showAddMenu(context),
      ));
    }

    // Add list-item button (direct or type-picker)
    if (theme.showAddButtons && (onAddItem != null || onAddItemWithType != null)) {
      actions.add(NodeAction(
        icon: Icons.playlist_add,
        tooltip: addItemTooltip,
        color: theme.structureColors.addButton,
        onPressed: onAddItemWithType != null
            ? () => _showAddItemTypeMenu(context)
            : onAddItem,
      ));
    }

    // Move-up button
    if (canMoveUp && onMoveUp != null) {
      actions.add(NodeAction(
        icon: Icons.arrow_upward,
        tooltip: 'Move up',
        color: theme.colors.hintColor,
        onPressed: onMoveUp,
      ));
    }

    // Move-down button
    if (canMoveDown && onMoveDown != null) {
      actions.add(NodeAction(
        icon: Icons.arrow_downward,
        tooltip: 'Move down',
        color: theme.colors.hintColor,
        onPressed: onMoveDown,
      ));
    }

    // Remove button
    if (theme.showRemoveButtons && canRemove && onRemove != null) {
      final removeAction = NodeAction(
        icon: Icons.close,
        tooltip: 'Remove',
        color: theme.structureColors.removeButton,
        onPressed: onRemove,
      );
      if (alwaysShowRemove) {
        pinnedRemoveAction = removeAction;
      } else {
        actions.add(removeAction);
      }
    }

    // Inspect button
    if (canInspect && onInspect != null) {
      actions.add(NodeAction(
        icon: Icons.code,
        tooltip: 'Edit as YAML',
        color: theme.colors.hintColor,
        onPressed: onInspect,
      ));
    }

    if (actions.isEmpty && pinnedRemoveAction == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (actions.isNotEmpty)
          NodeActionRow(
            visible: visible,
            actions: actions,
          ),
        if (pinnedRemoveAction != null && actions.isNotEmpty)
          const SizedBox(width: 2),
        if (pinnedRemoveAction != null)
          ActionButton(
            icon: pinnedRemoveAction.icon,
            tooltip: pinnedRemoveAction.tooltip,
            onPressed: pinnedRemoveAction.onPressed,
            size: pinnedRemoveAction.size,
            color: pinnedRemoveAction.color,
          ),
      ],
    );
  }

  void _showAddMenu(BuildContext context) {
    if (suggestedKeys.isEmpty) {
      _showManualAddDialog(context);
      return;
    }

    if (suggestedKeys.length == 1) {
      onAdd?.call(suggestedKeys.first);
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: suggestedKeys.map((key) {
        return PopupMenuItem<String>(
          value: key,
          height: 32,
          child: Text(key, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) onAdd?.call(selected);
    });
  }

  void _showAddItemTypeMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    showMenu<AddKeyType>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: AddKeyType.values
          .map((t) => PopupMenuItem<AddKeyType>(
                value: t,
                height: 32,
                child: Text(t.label, style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
    ).then((selected) {
      if (selected != null) onAddItemWithType?.call(selected.toValue());
    });
  }

  Future<void> _showManualAddDialog(BuildContext context) async {
    final result = await showAddKeyDialog(context);
    if (result == null) return;
    if (onAddWithType != null) {
      onAddWithType!(result.key, result.type.toValue());
    } else {
      onAdd?.call(result.key);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../yaml_editor_theme.dart';

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

  /// Whether this node can be inspected as raw YAML.
  final bool canInspect;

  /// Callback when a new key is added.
  final ValueChanged<String>? onAdd;

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
    this.canInspect = false,
    this.onAdd,
    this.onRemove,
    this.onInspect,
    this.visible = true,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || readOnly) return const SizedBox.shrink();

    var actions = <NodeAction>[];

    // Add button
    if (theme.showAddButtons && suggestedKeys.isNotEmpty && onAdd != null) {
      actions.add(NodeAction(
        icon: Icons.add,
        tooltip: 'Add key',
        color: theme.structureColors.addButton,
        onPressed: () => _showAddMenu(context),
      ));
    }

    // Remove button
    if (theme.showRemoveButtons && canRemove && onRemove != null) {
      actions.add(NodeAction(
        icon: Icons.close,
        tooltip: 'Remove',
        color: theme.structureColors.removeButton,
        onPressed: onRemove,
      ));
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

    if (actions.isEmpty) return const SizedBox.shrink();

    return NodeActionRow(
      visible: visible,
      actions: actions,
    );
  }

  void _showAddMenu(BuildContext context) {
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
}

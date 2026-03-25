import 'package:flutter/material.dart';

import '../components/forge_editor.dart';

/// Tab bar for the editor area.
///
/// Shows open editor tabs with file name, dirty indicator (*),
/// close button, and active tab highlight.
class ForgeEditorTabBar extends StatelessWidget {
  final List<ForgeEditor> editors;
  final ForgeEditor? activeEditor;
  final ValueChanged<ForgeEditor> onSelect;
  final ValueChanged<ForgeEditor> onClose;

  const ForgeEditorTabBar({
    super.key,
    required this.editors,
    this.activeEditor,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final editor in editors) _buildTab(context, editor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, ForgeEditor editor) {
    final isActive = editor == activeEditor;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onSelect(editor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.surfaceContainerHighest
              : null,
          border: isActive
              ? Border(
                  top: BorderSide(
                      color: theme.colorScheme.primary, width: 2))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(editor.icon, size: 14),
            const SizedBox(width: 4),
            ValueListenableBuilder<String>(
              valueListenable: editor.title,
              builder: (context, title, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: editor.isDirty,
                  builder: (context, isDirty, _) {
                    return Text(
                      isDirty ? '$title *' : title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => onClose(editor),
              child: Icon(
                Icons.close,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

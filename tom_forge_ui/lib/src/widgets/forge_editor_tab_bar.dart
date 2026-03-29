import 'package:flutter/material.dart';

import '../components/forge_editor.dart';

/// Tab bar for the editor area.
///
/// Shows open editor tabs with file name, dirty indicator (*),
/// close button, and active tab highlight.
class ForgeEditorTabBar extends StatefulWidget {
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
  State<ForgeEditorTabBar> createState() => _ForgeEditorTabBarState();
}

class _ForgeEditorTabBarState extends State<ForgeEditorTabBar> {
  ForgeEditor? _hoveredEditor;
  ForgeEditor? _hoveredCloseEditor;

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
              primary: false,
              physics: const ClampingScrollPhysics(),
              children: [
                for (final editor in widget.editors) _buildTab(context, editor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, ForgeEditor editor) {
    final isActive = editor == widget.activeEditor;
    final isHovered = _hoveredEditor == editor;
    final isCloseHovered = _hoveredCloseEditor == editor;
    final theme = Theme.of(context);
    final tabBackground = isActive
        ? theme.colorScheme.surfaceContainerHighest
        : (isHovered
            ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.45)
            : Colors.transparent);

    final closeColor = isCloseHovered
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredEditor = editor),
      onExit: (_) => setState(() {
        if (_hoveredEditor == editor) {
          _hoveredEditor = null;
        }
        if (_hoveredCloseEditor == editor) {
          _hoveredCloseEditor = null;
        }
      }),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelect(editor),
          hoverColor: theme.colorScheme.surfaceContainer.withValues(alpha: 0.35),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: tabBackground,
              border: isActive
                  ? Border(
                      top: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    )
                  : Border(
                      top: BorderSide(
                        color: Colors.transparent,
                        width: 2,
                      ),
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(editor.icon, size: 14),
                const SizedBox(width: 6),
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
                const SizedBox(width: 6),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredCloseEditor = editor),
                  onExit: (_) => setState(() {
                    if (_hoveredCloseEditor == editor) {
                      _hoveredCloseEditor = null;
                    }
                  }),
                  child: Tooltip(
                    message: 'Close',
                    child: InkResponse(
                      radius: 14,
                      onTap: () => widget.onClose(editor),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isCloseHovered
                              ? theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: closeColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

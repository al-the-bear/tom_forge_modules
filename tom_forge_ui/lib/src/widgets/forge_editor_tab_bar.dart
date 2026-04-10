import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/forge_editor.dart';
import '../theme/forge_shell_theme.dart';
import 'forge_drag_data.dart';
import 'forge_shell_scaffold.dart';

/// Callback for when a tab is dropped onto this tab bar from another panel.
/// [isCopy] is true when SHIFT was held during the drop (copy semantics).
typedef EditorDropCallback = void Function(ForgeEditor editor, {bool isCopy});

/// Callback for when a view section is dropped onto the editor tab bar.
typedef ViewDropCallback = void Function(SectionDragData data);

/// Callback for when a panel tab is dropped onto the editor tab bar.
typedef PanelTabDropCallback = void Function(PanelTabDragData data);

/// Tab bar for the editor area.
///
/// Shows open editor tabs with file name, dirty indicator (*),
/// close button, and active tab highlight. Tabs can be dragged
/// between panels.
class ForgeEditorTabBar extends StatefulWidget {
  final List<ForgeEditor> editors;
  final ForgeEditor? activeEditor;
  final ValueChanged<ForgeEditor> onSelect;
  final ValueChanged<ForgeEditor> onClose;

  /// Called when an editor tab from another panel is dropped here.
  final EditorDropCallback? onEditorDropped;

  /// Called when a view section is dropped here from a side/bottom panel.
  final ViewDropCallback? onViewDropped;

  /// Called when a panel tab is dropped here from a side/bottom panel.
  final PanelTabDropCallback? onPanelTabDropped;

  /// Called when "Close Others" is selected (receives list to close).
  final void Function(List<ForgeEditor>)? onCloseMultiple;

  /// Called when "Edit Action Bar" is selected.
  final ValueChanged<ForgeEditor>? onEditActionBar;

  /// Index of the panel this tab bar belongs to (for drag identity).
  final int panelIndex;

  const ForgeEditorTabBar({
    super.key,
    required this.editors,
    this.activeEditor,
    required this.onSelect,
    required this.onClose,
    this.onEditorDropped,
    this.onViewDropped,
    this.onPanelTabDropped,
    this.onCloseMultiple,
    this.onEditActionBar,
    this.panelIndex = 0,
  });

  @override
  State<ForgeEditorTabBar> createState() => _ForgeEditorTabBarState();
}

class _ForgeEditorTabBarState extends State<ForgeEditorTabBar> {
  ForgeEditor? _hoveredEditor;
  ForgeEditor? _hoveredCloseEditor;
  bool _isDragOver = false;
  final FocusNode _focusNode = FocusNode();

  /// Editor whose tab is currently expanded to show action icons.
  ForgeEditor? _expandedEditor;

  /// Timer that fires after 2 seconds of hover to expand the tab.
  Timer? _expandTimer;

  @override
  void dispose() {
    _focusNode.dispose();
    _expandTimer?.cancel();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final editors = widget.editors;
    if (editors.isEmpty) return;

    final activeIdx = widget.activeEditor != null
        ? editors.indexOf(widget.activeEditor!)
        : -1;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final next = (activeIdx - 1).clamp(0, editors.length - 1);
      widget.onSelect(editors[next]);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final next = (activeIdx + 1).clamp(0, editors.length - 1);
      widget.onSelect(editors[next]);
    } else if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (activeIdx >= 0) {
        widget.onClose(editors[activeIdx]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Editor tabs',
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: DragTarget<ForgeDragData>(
      onWillAcceptWithDetails: (details) {
        final accepted = switch (details.data) {
          TabDragData d => d.sourcePanelIndex != widget.panelIndex,
          SectionDragData _ => true, // Accept view drops from side panels
          PanelTabDragData _ => true, // Accept panel tab drops to middle
        };
        if (accepted) setState(() => _isDragOver = true);
        return accepted;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        switch (details.data) {
          case TabDragData data:
            final isCopy = HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftLeft) ||
                HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftRight);
            widget.onEditorDropped?.call(data.editor, isCopy: isCopy);
          case SectionDragData data:
            widget.onViewDropped?.call(data);
          case PanelTabDragData data:
            widget.onPanelTabDropped?.call(data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
        return AnimatedContainer(
          duration: ForgeAnimations.dropZoneFade,
          height: 32,
          decoration: BoxDecoration(
            color: _isDragOver
                ? (shellTheme?.dropZoneHighlight ?? theme.colorScheme.primary.withValues(alpha: 0.2))
                : theme.colorScheme.surface,
            border: _isDragOver
                ? Border(
                    bottom: BorderSide(
                      color: shellTheme?.dropZoneValid ?? theme.colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    for (final editor in widget.editors)
                      _buildTab(context, editor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
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

    final tabContent = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hoveredEditor = editor);
        // Start 2-second timer for tab expansion if editor has header actions.
        if (editor.headerActions.isNotEmpty) {
          _expandTimer?.cancel();
          _expandTimer = Timer(const Duration(seconds: 2), () {
            if (mounted && _hoveredEditor == editor) {
              setState(() => _expandedEditor = editor);
            }
          });
        }
      },
      onExit: (_) => setState(() {
        if (_hoveredEditor == editor) {
          _hoveredEditor = null;
        }
        if (_hoveredCloseEditor == editor) {
          _hoveredCloseEditor = null;
        }
        if (_expandedEditor == editor) {
          _expandedEditor = null;
        }
        _expandTimer?.cancel();
      }),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelect(editor),
          hoverColor: theme.colorScheme.surfaceContainer.withValues(alpha: 0.35),
          child: AnimatedContainer(
            duration: ForgeAnimations.tabTransition,
            curve: ForgeAnimations.tabCurve,
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
                // Show action icons when tab is expanded (after 2s hover)
                if (_expandedEditor == editor)
                  for (final action in editor.headerActions)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Tooltip(
                        message: action.label,
                        child: InkResponse(
                          radius: 12,
                          onTap: action.isEnabled()
                              ? () => action.execute({})
                              : null,
                          child: Icon(
                            action.icon ?? Icons.play_arrow,
                            size: 14,
                            color: action.isEnabled()
                                ? theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
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
                        duration: ForgeAnimations.tabTransition,
                        curve: ForgeAnimations.tabCurve,
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

    // Wrap tab in Draggable for cross-panel tab moves, with accessibility.
    return Semantics(
      selected: isActive,
      label: editor.title.value,
      hint: isActive ? 'Active editor tab' : 'Editor tab',
      child: GestureDetector(
        onSecondaryTapUp: (details) => _showTabContextMenu(
          details.globalPosition,
          editor,
        ),
        child: Draggable<TabDragData>(
          data: TabDragData(editor: editor, sourcePanelIndex: widget.panelIndex),
          feedback: MouseRegion(
            cursor: SystemMouseCursors.grabbing,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              child: Opacity(
                opacity: 0.85,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(editor.icon, size: 14, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 6),
                      ValueListenableBuilder<String>(
                        valueListenable: editor.title,
                        builder: (context, title, _) => Text(
                          title,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: tabContent,
          ),
          child: tabContent,
        ),
      ),
    );
  }

  /// Shows the tab context menu.
  Future<void> _showTabContextMenu(
    Offset globalPosition,
    ForgeEditor editor,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final editors = widget.editors;
    final editorIndex = editors.indexOf(editor);
    final hasOthers = editors.length > 1;
    final hasToRight = editorIndex >= 0 && editorIndex < editors.length - 1;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'close',
          child: Text('Close'),
        ),
        PopupMenuItem<String>(
          value: 'closeOthers',
          enabled: hasOthers,
          child: const Text('Close Others'),
        ),
        PopupMenuItem<String>(
          value: 'closeToRight',
          enabled: hasToRight,
          child: const Text('Close to the Right'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'closeAll',
          child: Text('Close All'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'editActionBar',
          child: Text('Edit Action Bar...'),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'close':
        widget.onClose(editor);
      case 'closeOthers':
        final toClose = editors.where((e) => e != editor).toList();
        if (widget.onCloseMultiple != null) {
          widget.onCloseMultiple!(toClose);
        } else {
          for (final e in toClose) {
            widget.onClose(e);
          }
        }
      case 'closeToRight':
        if (editorIndex >= 0) {
          final toClose = editors.sublist(editorIndex + 1);
          if (widget.onCloseMultiple != null) {
            widget.onCloseMultiple!(toClose);
          } else {
            for (final e in toClose) {
              widget.onClose(e);
            }
          }
        }
      case 'closeAll':
        if (widget.onCloseMultiple != null) {
          widget.onCloseMultiple!(List.from(editors));
        } else {
          for (final e in List.from(editors)) {
            widget.onClose(e);
          }
        }
      case 'editActionBar':
        widget.onEditActionBar?.call(editor);
    }
  }
}

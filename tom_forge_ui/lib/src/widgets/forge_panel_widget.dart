import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/forge_view.dart';
import '../model/forge_application.dart';
import '../theme/forge_shell_theme.dart';
import 'forge_drag_data.dart';
import 'forge_shell_scaffold.dart';

/// Position of vertical icon strip on side panels.
enum IconStripPosition { left, right }

/// Side panel widget with vertical icon strip (per concept §2.2, §2.3).
///
/// Features:
/// - Vertical icon strip on the panel edge
/// - Tabs activate via icon click
/// - Accordeon sections within each tab
/// - Configuration tab (⚙) pinned at bottom of left panel
/// - Tabs can be dragged between left/right/bottom panel areas
class ForgeSidePanelWidget extends StatefulWidget {
  final List<PanelTabConfig> tabs;
  final IconStripPosition iconStripPosition;
  final bool showConfigTab;
  final VoidCallback? onConfigTap;
  final WidgetBuilder? configurationPanelBuilder;

  /// External notifier to open/close the config panel from outside.
  final ValueNotifier<bool>? configPanelVisible;

  /// The panel area this side panel belongs to.
  final PanelArea panelArea;

  /// Called when a panel tab is dropped from another area.
  final void Function(PanelTabDragData data)? onTabDropped;

  /// Called when an editor tab from the middle panels is dropped here.
  final void Function(TabDragData data)? onEditorDropped;

  const ForgeSidePanelWidget({
    super.key,
    required this.tabs,
    required this.iconStripPosition,
    this.showConfigTab = false,
    this.onConfigTap,
    this.configurationPanelBuilder,
    this.configPanelVisible,
    this.panelArea = PanelArea.left,
    this.onTabDropped,
    this.onEditorDropped,
  });

  @override
  State<ForgeSidePanelWidget> createState() => _ForgeSidePanelWidgetState();
}

class _ForgeSidePanelWidgetState extends State<ForgeSidePanelWidget> {
  int _activeTabIndex = 0;
  bool _showConfigPanel = false;

  @override
  void initState() {
    super.initState();
    widget.configPanelVisible?.addListener(_onConfigPanelVisibleChanged);
  }

  @override
  void didUpdateWidget(covariant ForgeSidePanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configPanelVisible != widget.configPanelVisible) {
      oldWidget.configPanelVisible?.removeListener(_onConfigPanelVisibleChanged);
      widget.configPanelVisible?.addListener(_onConfigPanelVisibleChanged);
    }
  }

  @override
  void dispose() {
    widget.configPanelVisible?.removeListener(_onConfigPanelVisibleChanged);
    super.dispose();
  }

  void _onConfigPanelVisibleChanged() {
    final visible = widget.configPanelVisible?.value ?? false;
    if (visible != _showConfigPanel) {
      setState(() => _showConfigPanel = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty && !widget.showConfigTab) {
      return _SidePanelEmptyPlaceholder(
        panelArea: widget.panelArea,
        onTabDropped: widget.onTabDropped,
        onEditorDropped: widget.onEditorDropped,
      );
    }

    final hasTabs = widget.tabs.isNotEmpty;
    final activeTab = hasTabs
        ? widget.tabs[_activeTabIndex.clamp(0, widget.tabs.length - 1)]
        : null;

    final iconStrip = _buildVerticalIconStrip(context);
    final content = Expanded(
      child: _showConfigPanel
          ? _buildConfigurationPanel(context)
          : _buildContent(context, activeTab),
    );

    // Position icon strip on left or right edge
    return Row(
      children: widget.iconStripPosition == IconStripPosition.left
          ? [iconStrip, content]
          : [content, iconStrip],
    );
  }

  Widget _buildVerticalIconStrip(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<ForgeDragData>(
      onWillAcceptWithDetails: (details) {
        return switch (details.data) {
          PanelTabDragData d => d.sourceArea != widget.panelArea,
          TabDragData _ => true, // Accept editor tabs from middle panels
          SectionDragData _ => true, // Accept sections from other panels
        };
      },
      onAcceptWithDetails: (details) {
        switch (details.data) {
          case PanelTabDragData data:
            widget.onTabDropped?.call(data);
          case TabDragData data:
            widget.onEditorDropped?.call(data);
          case SectionDragData _:
            break; // Section reorder handled by accordion
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        final shellTheme = theme.extension<ForgeShellTheme>();
        return AnimatedContainer(
          duration: ForgeAnimations.dropZoneFade,
          width: ForgeDimensions.sideTabBarCollapsed,
          color: isDropTarget
              ? (shellTheme?.dropZoneHighlight ?? theme.colorScheme.primary.withValues(alpha: 0.2))
              : theme.colorScheme.surface,
          child: Column(
            children: [
              // User tabs (draggable)
              for (var i = 0; i < widget.tabs.length; i++)
                Draggable<PanelTabDragData>(
                  data: PanelTabDragData(
                    title: widget.tabs[i].title,
                    tabIndex: i,
                    sourceArea: widget.panelArea,
                    sections: widget.tabs[i].sections,
                  ),
                  feedback: _buildTabDragFeedback(context, widget.tabs[i]),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _buildIconTab(context, i, widget.tabs[i]),
                  ),
                  child: _buildIconTab(context, i, widget.tabs[i]),
                ),
              const Spacer(),
              // Add tab button
              _buildAddTabButton(context),
              // Divider before config tab (per concept §2.2)
              if (widget.showConfigTab) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                // Configuration tab (pinned at bottom, per concept §2.2)
                _buildConfigTab(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabDragFeedback(BuildContext context, PanelTabConfig tab) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      child: MouseRegion(
        cursor: SystemMouseCursors.grabbing,
        child: Opacity(
          opacity: 0.85,
          child: Container(
            width: ForgeDimensions.sideTabBarCollapsed,
            height: ForgeDimensions.sideTabBarCollapsed,
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(tab.icon, size: ForgeDimensions.iconTab,
                color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildIconTab(BuildContext context, int index, PanelTabConfig tab) {
    final isActive = index == _activeTabIndex && !_showConfigPanel;
    final theme = Theme.of(context);

    return Tooltip(
      message: tab.title,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () => setState(() {
          _activeTabIndex = index;
          _showConfigPanel = false;
          widget.configPanelVisible?.value = false;
        }),
        child: Container(
          width: ForgeDimensions.sideTabBarCollapsed,
          height: ForgeDimensions.sideTabBarCollapsed,
          decoration: BoxDecoration(
            border: isActive
                ? Border(
                    left: widget.iconStripPosition == IconStripPosition.left
                        ? BorderSide(
                            color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                    right: widget.iconStripPosition == IconStripPosition.right
                        ? BorderSide(
                            color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                  )
                : null,
            color: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Icon(
            tab.icon,
            size: ForgeDimensions.iconTab,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTabButton(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Add Tab',
      child: InkWell(
        onTap: () {
          // TODO: Show tab picker dialog
        },
        child: SizedBox(
          width: ForgeDimensions.sideTabBarCollapsed,
          height: ForgeDimensions.sideTabBarCollapsed,
          child: Icon(
            Icons.add,
            size: ForgeDimensions.iconTab,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTab(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Configuration',
      child: InkWell(
        onTap: () {
          setState(() {
            _showConfigPanel = true;
            widget.configPanelVisible?.value = true;
          });
          if (widget.configurationPanelBuilder == null) {
            widget.onConfigTap?.call();
          }
        },
        child: Container(
          width: ForgeDimensions.sideTabBarCollapsed,
          height: ForgeDimensions.sideTabBarCollapsed,
          decoration: BoxDecoration(
            border: _showConfigPanel
                ? Border(
                    left: widget.iconStripPosition == IconStripPosition.left
                        ? BorderSide(
                            color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                    right: widget.iconStripPosition == IconStripPosition.right
                        ? BorderSide(
                            color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                  )
                : null,
            color: _showConfigPanel
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Icon(
            Icons.settings,
            size: ForgeDimensions.iconTab,
            color: _showConfigPanel
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PanelTabConfig? tab) {
    if (tab == null) {
      return Center(
        child: Text(
          'No tabs available',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    if (tab.sections.isEmpty) {
      return Center(
        child: Text(
          'No content',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    // Accordeon layout: stack views vertically with collapsible sections
    return _AccordeonLayout(
      sections: tab.sections,
      panelArea: widget.panelArea,
      tabIndex: _activeTabIndex,
    );
  }

  Widget _buildConfigurationPanel(BuildContext context) {
    final builder = widget.configurationPanelBuilder;
    if (builder != null) {
      return builder(context);
    }
    return Center(
      child: Text(
        'No configuration panel available',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
      ),
    );
  }
}

/// Accordeon layout for panel sections (per concept §3).
///
/// Features mutual exclusivity (default) and pinning for multiple open sections.
class _AccordeonLayout extends StatefulWidget {
  final List<ForgeView> sections;
  final PanelArea? panelArea;
  final int? tabIndex;

  const _AccordeonLayout({
    required this.sections,
    this.panelArea,
    this.tabIndex,
  });

  @override
  State<_AccordeonLayout> createState() => _AccordeonLayoutState();
}

class _AccordeonLayoutState extends State<_AccordeonLayout> {
  final Set<int> _expandedSections = {0}; // First section open by default
  final Set<int> _pinnedSections = {};
  /// Flex factors for expanded sections (default 1.0 each).
  final Map<int, double> _sectionFlex = {};
  /// Keyboard-focused section index (-1 = none).
  int _focusedSection = -1;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _flexFor(int index) => _sectionFlex[index] ?? 1.0;

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedSection = (_focusedSection + 1).clamp(0, widget.sections.length - 1);
      });
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedSection = (_focusedSection - 1).clamp(0, widget.sections.length - 1);
      });
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (_focusedSection >= 0 && _focusedSection < widget.sections.length) {
        _toggleSection(_focusedSection);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If only one section, it's always expanded (per concept §3.2)
    if (widget.sections.length == 1) {
      return widget.sections.first.buildMain(context);
    }

    final expandedIndices =
        List.generate(widget.sections.length, (i) => i)
            .where(_expandedSections.contains)
            .toList();

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
      children: [
        for (var i = 0; i < widget.sections.length; i++) ...[
          // Reorder drop target above section header
          DragTarget<SectionDragData>(
            onWillAcceptWithDetails: (details) {
              return details.data.sourceIndex != i &&
                  details.data.sourceIndex != i - 1;
            },
            onAcceptWithDetails: (details) =>
                _reorderSection(details.data.sourceIndex, i),
            builder: (context, candidateData, rejectedData) {
              final isDropTarget = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: ForgeAnimations.dropZoneFade,
                height: isDropTarget ? 4 : 0,
                color: isDropTarget
                    ? (Theme.of(context).extension<ForgeShellTheme>()
                            ?.dropZoneValid ??
                        Theme.of(context).colorScheme.primary)
                    : Colors.transparent,
              );
            },
          ),
          // Draggable section header
          Draggable<SectionDragData>(
            data: SectionDragData(
              section: widget.sections[i],
              sourceIndex: i,
              sourceArea: widget.panelArea,
              sourceTabIndex: widget.tabIndex,
            ),
            feedback: _buildDragFeedback(context, widget.sections[i]),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _AccordeonSectionHeader(
                view: widget.sections[i],
                isExpanded: false,
                isPinned: false,
                onToggle: () {},
                onTogglePin: () {},
              ),
            ),
            child: _AccordeonSectionHeader(
              view: widget.sections[i],
              isExpanded: _expandedSections.contains(i),
              isPinned: _pinnedSections.contains(i),
              isFocused: _focusedSection == i,
              onToggle: () => _toggleSection(i),
              onTogglePin: () => _togglePin(i),
              onClose: widget.sections.length > 1
                  ? () => _hideSection(i)
                  : null,
            ),
          ),
          // Section content (expanded sections get flexible space)
          if (_expandedSections.contains(i))
            Flexible(
              flex: (_flexFor(i) * 1000).round(),
              child: widget.sections[i].buildMain(context),
            ),
          // Drag divider between adjacent expanded sections
          if (_expandedSections.contains(i) &&
              _hasNextExpandedSection(i, expandedIndices))
            _AccordeonDivider(
              onDragDelta: (delta) => _resizeSections(
                i,
                _nextExpandedSection(i, expandedIndices)!,
                delta,
              ),
              onDoubleTap: () => _resetSectionFlex(),
            ),
        ],
      ],
    ),
    );
  }

  void _hideSection(int index) {
    setState(() {
      _expandedSections.remove(index);
      _pinnedSections.remove(index);
      // Ensure at least one section remains expanded
      if (_expandedSections.isEmpty) {
        for (var i = 0; i < widget.sections.length; i++) {
          if (i != index) {
            _expandedSections.add(i);
            break;
          }
        }
      }
    });
  }

  bool _hasNextExpandedSection(int current, List<int> expandedIndices) {
    final currentPos = expandedIndices.indexOf(current);
    return currentPos >= 0 && currentPos < expandedIndices.length - 1;
  }

  int? _nextExpandedSection(int current, List<int> expandedIndices) {
    final currentPos = expandedIndices.indexOf(current);
    if (currentPos >= 0 && currentPos < expandedIndices.length - 1) {
      return expandedIndices[currentPos + 1];
    }
    return null;
  }

  void _resizeSections(int topIdx, int bottomIdx, double delta) {
    const minFlex = 0.15;
    final topFlex = _flexFor(topIdx);
    final bottomFlex = _flexFor(bottomIdx);
    final totalFlex = topFlex + bottomFlex;
    final flexDelta = delta / 200.0;
    final newTop = (topFlex + flexDelta).clamp(minFlex, totalFlex - minFlex);
    setState(() {
      _sectionFlex[topIdx] = newTop;
      _sectionFlex[bottomIdx] = totalFlex - newTop;
    });
  }

  void _resetSectionFlex() {
    setState(() => _sectionFlex.clear());
  }

  void _reorderSection(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    setState(() {
      final wasExpanded = _expandedSections.contains(fromIndex);
      final wasPinned = _pinnedSections.contains(fromIndex);
      // Adjust target index when moving down.
      final effectiveTo = toIndex > fromIndex ? toIndex - 1 : toIndex;

      // Rebuild expanded/pinned sets with reordered indices.
      final newExpanded = <int>{};
      final newPinned = <int>{};
      for (final idx in _expandedSections) {
        if (idx == fromIndex) continue;
        final adjusted = idx > fromIndex ? idx - 1 : idx;
        final final_ = adjusted >= effectiveTo ? adjusted + 1 : adjusted;
        newExpanded.add(final_);
      }
      for (final idx in _pinnedSections) {
        if (idx == fromIndex) continue;
        final adjusted = idx > fromIndex ? idx - 1 : idx;
        final final_ = adjusted >= effectiveTo ? adjusted + 1 : adjusted;
        newPinned.add(final_);
      }
      if (wasExpanded) newExpanded.add(effectiveTo);
      if (wasPinned) newPinned.add(effectiveTo);

      _expandedSections
        ..clear()
        ..addAll(newExpanded);
      _pinnedSections
        ..clear()
        ..addAll(newPinned);
      _sectionFlex.clear();

      // Notify parent about the reorder.
      _onReorder?.call(fromIndex, effectiveTo);
    });
  }

  /// Callback set by parent to actually reorder the section list.
  VoidCallback? Function(int from, int to)? get _onReorder => null;

  Widget _buildDragFeedback(BuildContext context, ForgeView view) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(4),
      child: MouseRegion(
        cursor: SystemMouseCursors.grabbing,
        child: Opacity(
          opacity: 0.85,
          child: Container(
            height: ForgeDimensions.sectionHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_indicator, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                ValueListenableBuilder<String>(
                  valueListenable: view.title,
                  builder: (context, title, _) => Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
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

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        // Can't collapse if it's the only expanded and unpinned section
        if (_expandedSections.length > 1) {
          _expandedSections.remove(index);
        }
      } else {
        // Per concept §3.2: opening one collapses others (unless pinned)
        _expandedSections
            .removeWhere((i) => !_pinnedSections.contains(i) && i != index);
        _expandedSections.add(index);
      }
    });
  }

  void _togglePin(int index) {
    setState(() {
      if (_pinnedSections.contains(index)) {
        _pinnedSections.remove(index);
      } else {
        _pinnedSections.add(index);
        _expandedSections.add(index);
      }
    });
  }
}

class _AccordeonSectionHeader extends StatelessWidget {
  final ForgeView view;
  final bool isExpanded;
  final bool isPinned;
  final bool isFocused;
  final VoidCallback onToggle;
  final VoidCallback onTogglePin;
  final VoidCallback? onClose;

  const _AccordeonSectionHeader({
    required this.view,
    required this.isExpanded,
    required this.isPinned,
    this.isFocused = false,
    required this.onToggle,
    required this.onTogglePin,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();

    return Semantics(
      button: true,
      label: 'Section: ${view.title.value}',
      expanded: isExpanded,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          height: ForgeDimensions.sectionHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: isFocused
                ? Border.all(
                    color: shellTheme?.focusRing ?? theme.colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Triangle icon (down when expanded, right when collapsed)
              Icon(
                isExpanded
                    ? Icons.arrow_drop_down
                    : Icons.arrow_right,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              // Title
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: view.title,
                  builder: (context, title, _) => Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Pin button
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onTogglePin,
                tooltip: isPinned ? 'Unpin' : 'Pin',
                color: isPinned
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              // Close/hide button (not shown for single-section tabs)
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: onClose,
                  tooltip: 'Hide section',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draggable divider between pinned-open accordeon sections.
class _AccordeonDivider extends StatefulWidget {
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDoubleTap;

  const _AccordeonDivider({
    required this.onDragDelta,
    this.onDoubleTap,
  });

  @override
  State<_AccordeonDivider> createState() => _AccordeonDividerState();
}

class _AccordeonDividerState extends State<_AccordeonDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary.withValues(alpha: 0.9);
    final hoverColor = theme.colorScheme.primary.withValues(alpha: 0.45);
    final idleColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final color = _isDragging ? activeColor : (_isHovering ? hoverColor : idleColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTap,
      onVerticalDragStart: (_) => setState(() => _isDragging = true),
      onVerticalDragUpdate: (d) => widget.onDragDelta(d.delta.dy),
      onVerticalDragEnd: (_) => setState(() => _isDragging = false),
      onVerticalDragCancel: () => setState(() => _isDragging = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() {
          _isHovering = false;
          _isDragging = false;
        }),
        child: SizedBox(
          height: 8,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: _isDragging ? 3.0 : (_isHovering ? 2.0 : 1.0),
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal accordeon layout for bottom panel sections (per concept §3.1).
///
/// Unlike the vertical [_AccordeonLayout] used in side panels, this arranges
/// sections horizontally. Expanded sections show a horizontal header bar with
/// content below. Collapsed sections appear as narrow vertical strips with
/// rotated text flowing top to bottom.
class _BottomAccordeonLayout extends StatefulWidget {
  final List<ForgeView> sections;
  final PanelArea? panelArea;
  final int? tabIndex;

  /// Called when an editor tab from the middle panel is dropped on the
  /// accordion content area (as opposed to the tab bar).
  final void Function(TabDragData data)? onEditorDroppedAsSection;

  const _BottomAccordeonLayout({
    required this.sections,
    this.panelArea,
    this.tabIndex,
    this.onEditorDroppedAsSection,
  });

  @override
  State<_BottomAccordeonLayout> createState() => _BottomAccordeonLayoutState();
}

class _BottomAccordeonLayoutState extends State<_BottomAccordeonLayout> {
  final Set<int> _expandedSections = {0};
  final Set<int> _pinnedSections = {};
  final Map<int, double> _sectionFlex = {};

  double _flexFor(int index) => _sectionFlex[index] ?? 1.0;

  Widget _buildDragFeedback(BuildContext context, ForgeView view) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(4),
      child: Opacity(
        opacity: 0.85,
        child: Container(
          height: ForgeDimensions.sectionHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF252526),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              ValueListenableBuilder<String>(
                valueListenable: view.title,
                builder: (context, title, _) => Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.length == 1) {
      return DragTarget<TabDragData>(
        onWillAcceptWithDetails: (_) =>
            widget.onEditorDroppedAsSection != null,
        onAcceptWithDetails: (details) =>
            widget.onEditorDroppedAsSection?.call(details.data),
        builder: (context, candidateData, _) {
          final child = widget.sections.first.buildMain(context);
          if (candidateData.isEmpty) return child;
          final shellTheme =
              Theme.of(context).extension<ForgeShellTheme>();
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: shellTheme?.dropZoneValid ??
                    Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            child: child,
          );
        },
      );
    }

    final expandedIndices = List.generate(widget.sections.length, (i) => i)
        .where(_expandedSections.contains)
        .toList();

    return DragTarget<TabDragData>(
      onWillAcceptWithDetails: (_) =>
          widget.onEditorDroppedAsSection != null,
      onAcceptWithDetails: (details) =>
          widget.onEditorDroppedAsSection?.call(details.data),
      builder: (context, candidateData, _) {
        final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.sections.length; i++) ...[
          if (_expandedSections.contains(i))
            Flexible(
              flex: (_flexFor(i) * 1000).round(),
              child: Column(
                children: [
                  Draggable<SectionDragData>(
                    data: SectionDragData(
                      section: widget.sections[i],
                      sourceIndex: i,
                      sourceArea: widget.panelArea,
                      sourceTabIndex: widget.tabIndex,
                    ),
                    feedback: _buildDragFeedback(context, widget.sections[i]),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _BottomSectionHeader(
                        view: widget.sections[i],
                        isExpanded: true,
                        isPinned: _pinnedSections.contains(i),
                        onToggle: () {},
                        onTogglePin: () {},
                      ),
                    ),
                    child: _BottomSectionHeader(
                      view: widget.sections[i],
                      isExpanded: true,
                      isPinned: _pinnedSections.contains(i),
                      onToggle: () => _toggleSection(i),
                      onTogglePin: () => _togglePin(i),
                    ),
                  ),
                  Expanded(child: widget.sections[i].buildMain(context)),
                ],
              ),
            )
          else
            _CollapsedVerticalStrip(
              view: widget.sections[i],
              isPinned: _pinnedSections.contains(i),
              onTap: () => _toggleSection(i),
              onTogglePin: () => _togglePin(i),
            ),
          // Horizontal divider between adjacent expanded sections.
          if (_expandedSections.contains(i) &&
              _hasNextExpandedSection(i, expandedIndices))
            _BottomAccordeonDivider(
              onDragDelta: (delta) => _resizeSections(
                i,
                _nextExpandedSection(i, expandedIndices)!,
                delta,
              ),
              onDoubleTap: () => setState(() => _sectionFlex.clear()),
            ),
        ],
      ],
    );
        if (candidateData.isEmpty) return row;
        final shellTheme =
            Theme.of(context).extension<ForgeShellTheme>();
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: shellTheme?.dropZoneValid ??
                  Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: row,
        );
      },
    );
  }

  bool _hasNextExpandedSection(int current, List<int> expandedIndices) {
    final currentPos = expandedIndices.indexOf(current);
    return currentPos >= 0 && currentPos < expandedIndices.length - 1;
  }

  int? _nextExpandedSection(int current, List<int> expandedIndices) {
    final currentPos = expandedIndices.indexOf(current);
    if (currentPos >= 0 && currentPos < expandedIndices.length - 1) {
      return expandedIndices[currentPos + 1];
    }
    return null;
  }

  void _resizeSections(int leftIdx, int rightIdx, double delta) {
    const minFlex = 0.15;
    final leftFlex = _flexFor(leftIdx);
    final rightFlex = _flexFor(rightIdx);
    final totalFlex = leftFlex + rightFlex;
    final flexDelta = delta / 200.0;
    final newLeft = (leftFlex + flexDelta).clamp(minFlex, totalFlex - minFlex);
    setState(() {
      _sectionFlex[leftIdx] = newLeft;
      _sectionFlex[rightIdx] = totalFlex - newLeft;
    });
  }

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        if (_expandedSections.length > 1) {
          _expandedSections.remove(index);
        }
      } else {
        _expandedSections
            .removeWhere((i) => !_pinnedSections.contains(i) && i != index);
        _expandedSections.add(index);
      }
    });
  }

  void _togglePin(int index) {
    setState(() {
      if (_pinnedSections.contains(index)) {
        _pinnedSections.remove(index);
      } else {
        _pinnedSections.add(index);
        _expandedSections.add(index);
      }
    });
  }
}

/// Horizontal header bar for an expanded bottom panel section.
class _BottomSectionHeader extends StatelessWidget {
  final ForgeView view;
  final bool isExpanded;
  final bool isPinned;
  final VoidCallback onToggle;
  final VoidCallback onTogglePin;

  const _BottomSectionHeader({
    required this.view,
    required this.isExpanded,
    required this.isPinned,
    required this.onToggle,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Container(
        height: ForgeDimensions.sectionHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: view.title,
                builder: (context, title, _) => Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 14,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onTogglePin,
              tooltip: isPinned ? 'Unpin' : 'Pin',
              color: isPinned
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Narrow vertical strip for collapsed bottom panel sections.
///
/// Title text is rotated 90° clockwise so it flows top to bottom,
/// matching the concept §3.1 specification for collapsed bottom sections.
class _CollapsedVerticalStrip extends StatefulWidget {
  final ForgeView view;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _CollapsedVerticalStrip({
    required this.view,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  State<_CollapsedVerticalStrip> createState() =>
      _CollapsedVerticalStripState();
}

class _CollapsedVerticalStripState extends State<_CollapsedVerticalStrip> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ForgeAnimations.dropZoneFade,
          width: 28,
          decoration: BoxDecoration(
            color: _isHovering
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHigh,
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Pin indicator at top.
              if (widget.isPinned)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.push_pin,
                    size: 10,
                    color: theme.colorScheme.primary,
                  ),
                ),
              // Rotated title text.
              Expanded(
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: ValueListenableBuilder<String>(
                      valueListenable: widget.view.title,
                      builder: (context, title, _) => Text(
                        title.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: _isHovering
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal drag divider between bottom panel expanded sections.
class _BottomAccordeonDivider extends StatefulWidget {
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDoubleTap;

  const _BottomAccordeonDivider({
    required this.onDragDelta,
    this.onDoubleTap,
  });

  @override
  State<_BottomAccordeonDivider> createState() =>
      _BottomAccordeonDividerState();
}

class _BottomAccordeonDividerState extends State<_BottomAccordeonDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary.withValues(alpha: 0.9);
    final hoverColor = theme.colorScheme.primary.withValues(alpha: 0.45);
    final idleColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    final color =
        _isDragging ? activeColor : (_isHovering ? hoverColor : idleColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTap,
      onHorizontalDragStart: (_) => setState(() => _isDragging = true),
      onHorizontalDragUpdate: (d) => widget.onDragDelta(d.delta.dx),
      onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
      onHorizontalDragCancel: () => setState(() => _isDragging = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() {
          _isHovering = false;
          _isDragging = false;
        }),
        child: SizedBox(
          width: 8,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _isDragging ? 3.0 : (_isHovering ? 2.0 : 1.0),
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom panel widget with horizontal tabs (icon + text).
///
/// Used for bottom panels per concept §2.5.
/// Bottom panel widget with horizontal tab bar and accordeon content.
///
/// Tabs are draggable between panel areas (left, right, bottom). The tab bar
/// acts as a drop target for tabs dragged from other panel areas.
class ForgePanelWidget extends StatefulWidget {
  final List<PanelTabConfig> tabs;

  /// Which panel area this bottom panel belongs to (default: bottom).
  final PanelArea panelArea;

  /// Called when a tab is dropped onto this panel from a different area.
  final void Function(PanelTabDragData data)? onTabDropped;

  /// Called when an editor tab from the middle panels is dropped here.
  final void Function(TabDragData data)? onEditorDropped;

  /// Called when an editor tab is dropped on the accordion content area
  /// of the active tab (to be added as an accordion section, not a new tab).
  final void Function(TabDragData data, int tabIndex)? onEditorDroppedAsSection;

  /// Called when a tab is right-clicked to show a context menu.
  final void Function(int tabIndex, Offset globalPosition)? onTabContextMenu;

  const ForgePanelWidget({
    super.key,
    required this.tabs,
    this.panelArea = PanelArea.bottom,
    this.onTabDropped,
    this.onEditorDropped,
    this.onEditorDroppedAsSection,
    this.onTabContextMenu,
  });

  @override
  State<ForgePanelWidget> createState() => _ForgePanelWidgetState();
}

class _ForgePanelWidgetState extends State<ForgePanelWidget> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return _BottomPanelEmptyPlaceholder(
        panelArea: widget.panelArea,
        onTabDropped: widget.onTabDropped,
        onEditorDropped: widget.onEditorDropped,
      );
    }

    final activeTab =
        widget.tabs[_activeTabIndex.clamp(0, widget.tabs.length - 1)];

    return Column(
      children: [
        _buildHorizontalTabBar(context),
        Expanded(child: _buildContent(context, activeTab)),
      ],
    );
  }

  Widget _buildHorizontalTabBar(BuildContext context) {
    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();
    return DragTarget<ForgeDragData>(
      onWillAcceptWithDetails: (details) {
        return switch (details.data) {
          PanelTabDragData d => d.sourceArea != widget.panelArea,
          TabDragData _ => true, // Accept editor tabs from middle panels
          SectionDragData _ => true, // Accept sections from other panels
        };
      },
      onAcceptWithDetails: (details) {
        switch (details.data) {
          case PanelTabDragData data:
            widget.onTabDropped?.call(data);
          case TabDragData data:
            widget.onEditorDropped?.call(data);
          case SectionDragData _:
            break;
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: ForgeAnimations.dropZoneFade,
          height: ForgeDimensions.tabBarHeight,
          color: isDropTarget
              ? (shellTheme?.dropZoneHighlight ?? theme.colorScheme.primary.withValues(alpha: 0.2))
              : theme.colorScheme.surface,
          child: Row(
            children: [
              for (var i = 0; i < widget.tabs.length; i++)
                Draggable<PanelTabDragData>(
                  data: PanelTabDragData(
                    title: widget.tabs[i].title,
                    tabIndex: i,
                    sourceArea: widget.panelArea,
                    sections: widget.tabs[i].sections,
                  ),
                  feedback: _buildHorizTabDragFeedback(context, widget.tabs[i]),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _buildHorizontalTab(context, i, widget.tabs[i]),
                  ),
                  child: _buildHorizontalTab(context, i, widget.tabs[i]),
                ),
              const Spacer(),
              // Add tab button
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {
                  // TODO: Show tab picker
                },
                tooltip: 'Add Tab',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizTabDragFeedback(BuildContext context, PanelTabConfig tab) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      child: MouseRegion(
        cursor: SystemMouseCursors.grabbing,
        child: Opacity(
          opacity: 0.85,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF252526),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: ForgeDimensions.iconToolbar,
                    color: Colors.white70),
                const SizedBox(width: 6),
                Text(tab.title,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalTab(
      BuildContext context, int index, PanelTabConfig tab) {
    final isActive = index == _activeTabIndex;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      onSecondaryTapDown: (details) {
        widget.onTabContextMenu?.call(index, details.globalPosition);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: isActive
              ? Border(
                  bottom: BorderSide(color: theme.colorScheme.primary, width: 2))
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: ForgeDimensions.iconToolbar,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              tab.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PanelTabConfig tab) {
    if (tab.sections.isEmpty) {
      return Center(
        child: Text(
          'No content',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    // Bottom panel uses horizontal accordeon (per concept §3.1)
    return _BottomAccordeonLayout(
      sections: tab.sections,
      panelArea: widget.panelArea,
      tabIndex: _activeTabIndex,
      onEditorDroppedAsSection: widget.onEditorDroppedAsSection != null
          ? (data) => widget.onEditorDroppedAsSection!(data, _activeTabIndex)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Drop placeholders for empty panels (Section 9, Row 9: placeholders persist)
// ---------------------------------------------------------------------------

/// Drop placeholder shown when a side panel has no tabs.
class _SidePanelEmptyPlaceholder extends StatefulWidget {
  final PanelArea panelArea;
  final void Function(PanelTabDragData data)? onTabDropped;
  final void Function(TabDragData data)? onEditorDropped;

  const _SidePanelEmptyPlaceholder({
    required this.panelArea,
    this.onTabDropped,
    this.onEditorDropped,
  });

  @override
  State<_SidePanelEmptyPlaceholder> createState() =>
      _SidePanelEmptyPlaceholderState();
}

class _SidePanelEmptyPlaceholderState
    extends State<_SidePanelEmptyPlaceholder> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();
    return DragTarget<ForgeDragData>(
      onWillAcceptWithDetails: (details) {
        return switch (details.data) {
          PanelTabDragData d => d.sourceArea != widget.panelArea,
          TabDragData _ => true,
          SectionDragData _ => true,
        };
      },
      onAcceptWithDetails: (details) {
        switch (details.data) {
          case PanelTabDragData data:
            widget.onTabDropped?.call(data);
          case TabDragData data:
            widget.onEditorDropped?.call(data);
          case SectionDragData _:
            break;
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: AnimatedContainer(
            duration: ForgeAnimations.dropZoneFade,
            width: ForgeDimensions.sideTabBarCollapsed,
            decoration: BoxDecoration(
              color: isDropTarget
                  ? (shellTheme?.dropZoneHighlight ??
                      theme.colorScheme.primary.withValues(alpha: 0.2))
                  : theme.colorScheme.surface.withValues(alpha: 0.5),
              border: isDropTarget
                  ? Border.all(
                      color: shellTheme?.dropZoneValid ??
                          const Color(0x5500CC66),
                      width: 2)
                  : null,
            ),
            child: Center(
              child: AnimatedOpacity(
                duration: ForgeAnimations.dropZoneFade,
                opacity: isDropTarget || _isHovering ? 0.8 : 0.3,
                child: Icon(
                  Icons.add_circle_outline,
                  size: 24,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drop placeholder shown when the bottom panel has no tabs.
class _BottomPanelEmptyPlaceholder extends StatefulWidget {
  final PanelArea panelArea;
  final void Function(PanelTabDragData data)? onTabDropped;
  final void Function(TabDragData data)? onEditorDropped;

  const _BottomPanelEmptyPlaceholder({
    required this.panelArea,
    this.onTabDropped,
    this.onEditorDropped,
  });

  @override
  State<_BottomPanelEmptyPlaceholder> createState() =>
      _BottomPanelEmptyPlaceholderState();
}

class _BottomPanelEmptyPlaceholderState
    extends State<_BottomPanelEmptyPlaceholder> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();
    return DragTarget<ForgeDragData>(
      onWillAcceptWithDetails: (details) {
        return switch (details.data) {
          PanelTabDragData d => d.sourceArea != widget.panelArea,
          TabDragData _ => true,
          SectionDragData _ => true,
        };
      },
      onAcceptWithDetails: (details) {
        switch (details.data) {
          case PanelTabDragData data:
            widget.onTabDropped?.call(data);
          case TabDragData data:
            widget.onEditorDropped?.call(data);
          case SectionDragData _:
            break;
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: ForgeAnimations.dropZoneFade,
          decoration: BoxDecoration(
            color: isDropTarget
                ? (shellTheme?.dropZoneHighlight ??
                    theme.colorScheme.primary.withValues(alpha: 0.2))
                : theme.colorScheme.surface.withValues(alpha: 0.5),
            border: isDropTarget
                ? Border.all(
                    color: shellTheme?.dropZoneValid ??
                        const Color(0x5500CC66),
                    width: 2)
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.vertical_align_bottom,
                  size: 24,
                  color: isDropTarget
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Drop panel here',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDropTarget
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

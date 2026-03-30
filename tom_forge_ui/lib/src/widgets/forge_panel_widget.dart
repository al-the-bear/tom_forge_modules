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

  /// The panel area this side panel belongs to.
  final PanelArea panelArea;

  /// Called when a panel tab is dropped from another area.
  final void Function(PanelTabDragData data)? onTabDropped;

  const ForgeSidePanelWidget({
    super.key,
    required this.tabs,
    required this.iconStripPosition,
    this.showConfigTab = false,
    this.onConfigTap,
    this.configurationPanelBuilder,
    this.panelArea = PanelArea.left,
    this.onTabDropped,
  });

  @override
  State<ForgeSidePanelWidget> createState() => _ForgeSidePanelWidgetState();
}

class _ForgeSidePanelWidgetState extends State<ForgeSidePanelWidget> {
  int _activeTabIndex = 0;
  bool _showConfigPanel = false;

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty && !widget.showConfigTab) {
      return _SidePanelEmptyPlaceholder(
        panelArea: widget.panelArea,
        onTabDropped: widget.onTabDropped,
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
    return DragTarget<PanelTabDragData>(
      onWillAcceptWithDetails: (details) {
        // Accept tabs from different panel areas.
        return details.data.sourceArea != widget.panelArea;
      },
      onAcceptWithDetails: (details) {
        widget.onTabDropped?.call(details.data);
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
    final isActive = index == _activeTabIndex;
    final theme = Theme.of(context);

    return Tooltip(
      message: tab.title,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () => setState(() {
          _activeTabIndex = index;
          _showConfigPanel = false;
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
          });
          if (widget.configurationPanelBuilder == null) {
            widget.onConfigTap?.call();
          }
        },
        child: SizedBox(
          width: ForgeDimensions.sideTabBarCollapsed,
          height: ForgeDimensions.sideTabBarCollapsed,
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
    return _AccordeonLayout(sections: tab.sections);
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

  const _AccordeonLayout({required this.sections});

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

    return Semantics(
      button: true,
      label: 'Section header',
      child: InkWell(
        onTap: onToggle,
        child: Container(
          height: ForgeDimensions.sectionHeaderHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: isFocused
                ? Border.all(color: theme.colorScheme.primary, width: 1)
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

  const ForgePanelWidget({
    super.key,
    required this.tabs,
    this.panelArea = PanelArea.bottom,
    this.onTabDropped,
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
    return DragTarget<PanelTabDragData>(
      onWillAcceptWithDetails: (details) {
        return details.data.sourceArea != widget.panelArea;
      },
      onAcceptWithDetails: (details) {
        widget.onTabDropped?.call(details.data);
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

    // Bottom panel uses accordeon with horizontal collapsed view
    return _AccordeonLayout(sections: tab.sections);
  }
}

// ---------------------------------------------------------------------------
// Drop placeholders for empty panels (Section 9, Row 9: placeholders persist)
// ---------------------------------------------------------------------------

/// Drop placeholder shown when a side panel has no tabs.
class _SidePanelEmptyPlaceholder extends StatefulWidget {
  final PanelArea panelArea;
  final void Function(PanelTabDragData data)? onTabDropped;

  const _SidePanelEmptyPlaceholder({
    required this.panelArea,
    this.onTabDropped,
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
    return DragTarget<PanelTabDragData>(
      onWillAcceptWithDetails: (details) {
        return details.data.sourceArea != widget.panelArea;
      },
      onAcceptWithDetails: (details) {
        widget.onTabDropped?.call(details.data);
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

  const _BottomPanelEmptyPlaceholder({
    required this.panelArea,
    this.onTabDropped,
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
    return DragTarget<PanelTabDragData>(
      onWillAcceptWithDetails: (details) {
        return details.data.sourceArea != widget.panelArea;
      },
      onAcceptWithDetails: (details) {
        widget.onTabDropped?.call(details.data);
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

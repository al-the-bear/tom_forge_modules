import 'package:flutter/material.dart';

import '../components/forge_view.dart';
import '../model/forge_application.dart';
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
class ForgeSidePanelWidget extends StatefulWidget {
  final List<PanelTabConfig> tabs;
  final IconStripPosition iconStripPosition;
  final bool showConfigTab;
  final VoidCallback? onConfigTap;
  final WidgetBuilder? configurationPanelBuilder;

  const ForgeSidePanelWidget({
    super.key,
    required this.tabs,
    required this.iconStripPosition,
    this.showConfigTab = false,
    this.onConfigTap,
    this.configurationPanelBuilder,
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
      return const SizedBox.expand();
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
    return Container(
      width: ForgeDimensions.sideTabBarCollapsed,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // User tabs
          for (var i = 0; i < widget.tabs.length; i++)
            _buildIconTab(context, i, widget.tabs[i]),
          const Spacer(),
          // Add tab button
          _buildAddTabButton(context),
          // Divider before config tab (per concept §2.2)
          if (widget.showConfigTab) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  @override
  Widget build(BuildContext context) {
    // If only one section, it's always expanded (per concept §3.2)
    if (widget.sections.length == 1) {
      return widget.sections.first.buildMain(context);
    }

    return ListView.builder(
      itemCount: widget.sections.length,
      itemBuilder: (context, index) {
        final view = widget.sections[index];
        final isExpanded = _expandedSections.contains(index);
        final isPinned = _pinnedSections.contains(index);

        return _AccordeonSection(
          view: view,
          isExpanded: isExpanded,
          isPinned: isPinned,
          onToggle: () => _toggleSection(index),
          onTogglePin: () => _togglePin(index),
        );
      },
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

class _AccordeonSection extends StatelessWidget {
  final ForgeView view;
  final bool isExpanded;
  final bool isPinned;
  final VoidCallback onToggle;
  final VoidCallback onTogglePin;

  const _AccordeonSection({
    required this.view,
    required this.isExpanded,
    required this.isPinned,
    required this.onToggle,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header with triangle icon and title
        InkWell(
          onTap: onToggle,
          child: Container(
            height: ForgeDimensions.sectionHeaderHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: theme.colorScheme.surfaceContainerHighest,
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
              ],
            ),
          ),
        ),
        // Section content (only when expanded)
        if (isExpanded)
          AnimatedSize(
            duration: ForgeAnimations.panelTransition,
            curve: ForgeAnimations.panelCurve,
            child: SizedBox(
              height: 200, // Default section height; could be configurable
              child: view.buildMain(context),
            ),
          ),
      ],
    );
  }
}

/// Bottom panel widget with horizontal tabs (icon + text).
///
/// Used for bottom panels per concept §2.5.
class ForgePanelWidget extends StatefulWidget {
  final List<PanelTabConfig> tabs;

  const ForgePanelWidget({super.key, required this.tabs});

  @override
  State<ForgePanelWidget> createState() => _ForgePanelWidgetState();
}

class _ForgePanelWidgetState extends State<ForgePanelWidget> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) return const SizedBox.expand();

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
    return Container(
      height: ForgeDimensions.tabBarHeight,
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _buildHorizontalTab(context, i, widget.tabs[i]),
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

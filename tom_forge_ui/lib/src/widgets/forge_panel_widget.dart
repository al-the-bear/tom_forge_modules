import 'package:flutter/material.dart';

import '../components/forge_view.dart';
import '../model/forge_application.dart';

/// Reusable panel container rendering [ForgeView] instances.
///
/// Supports tabbed switching between multiple views and
/// collapse/expand via a visibility toggle.
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

    final activeTab = widget.tabs[_activeTabIndex.clamp(0, widget.tabs.length - 1)];

    return Column(
      children: [
        _buildTabBar(context),
        Expanded(child: _buildContent(context, activeTab)),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 28,
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            _buildTab(context, i, widget.tabs[i]),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index, PanelTabConfig tab) {
    final isActive = index == _activeTabIndex;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: isActive
              ? Border(
                  bottom:
                      BorderSide(color: theme.colorScheme.primary, width: 2))
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 14, color: theme.colorScheme.onSurface),
            const SizedBox(width: 4),
            Text(
              tab.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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

    // Accordion layout: stack views vertically.
    return ListView(
      children: [
        for (final view in tab.sections) _buildSection(context, view),
      ],
    );
  }

  Widget _buildSection(BuildContext context, ForgeView view) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.centerLeft,
          child: ValueListenableBuilder<String>(
            valueListenable: view.title,
            builder: (context, title, _) => Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        view.buildMain(context),
      ],
    );
  }
}

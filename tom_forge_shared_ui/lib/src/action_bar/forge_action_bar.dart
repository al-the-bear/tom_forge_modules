import 'package:flutter/material.dart';

import '../forge_dimensions.dart';
import 'forge_action_item.dart';

/// A row of icon buttons in groups — Forge's title-bar action bar, and any
/// row of actions an application beside Forge shows (Webwork's icon bar).
///
/// Each button follows its item's [ForgeActionItem.enabled]; groups are set
/// apart by a vertical divider. When the row is narrower than the buttons,
/// those that do not fit move into an overflow menu (a `more` button at the
/// end), in order; an unbounded row shows them all. An empty bar takes no
/// space.
class ForgeActionBar extends StatelessWidget {
  const ForgeActionBar({
    super.key,
    required this.groups,
    this.iconSize = ForgeDimensions.iconToolbar,
  });

  final List<ForgeActionGroup> groups;
  final double iconSize;

  /// The width of one button: the icon and its padding.
  double get buttonExtent => iconSize + 2 * _padding;

  /// The width of the divider between two groups.
  static const double dividerExtent = 9;

  static const double _padding = 4;

  @override
  Widget build(BuildContext context) {
    final groups = this.groups.where((g) => g.items.isNotEmpty).toList();
    if (groups.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildRow(context, groups, constraints.maxWidth),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<ForgeActionGroup> groups,
    double maxWidth,
  ) {
    // Lay the groups out in order until the next button would leave no room
    // for the overflow button.
    final children = <Widget>[];
    final overflow = <ForgeActionItem>[];
    final total =
        groups.fold<double>(0, (w, g) => w + g.items.length * buttonExtent) +
        (groups.length - 1) * dividerExtent;
    final fitsAll = total <= maxWidth;
    var used = 0.0;
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      if (g > 0) {
        if (overflow.isEmpty &&
            (fitsAll || used + dividerExtent + buttonExtent * 2 <= maxWidth)) {
          children.add(
            const SizedBox(
              width: dividerExtent,
              height: 24,
              child: VerticalDivider(width: dividerExtent),
            ),
          );
          used += dividerExtent;
        } else {
          overflow.addAll(group.items);
          continue;
        }
      }
      for (final item in group.items) {
        if (overflow.isEmpty &&
            (fitsAll || used + buttonExtent * 2 <= maxWidth)) {
          children.add(_buildButton(context, item));
          used += buttonExtent;
        } else {
          overflow.add(item);
        }
      }
    }
    if (overflow.isNotEmpty) children.add(_buildOverflow(context, overflow));
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildButton(BuildContext context, ForgeActionItem item) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      key: ValueKey('forge.actionBar.${item.id}'),
      valueListenable: item.enabled,
      builder: (context, _, _) {
        final isEnabled = item.isEnabled;
        return Tooltip(
          message: item.tooltip,
          child: InkWell(
            onTap: isEnabled ? item.onInvoke : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: Icon(
                item.icon,
                size: iconSize,
                color: isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverflow(BuildContext context, List<ForgeActionItem> items) {
    final theme = Theme.of(context);
    return PopupMenuButton<ForgeActionItem>(
      key: const ValueKey('forge.actionBar.overflow'),
      tooltip: 'More actions',
      onSelected: (item) => item.onInvoke?.call(),
      // As wide as a button, so the layout above holds.
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Icon(
          Icons.more_horiz,
          size: iconSize,
          color: theme.colorScheme.onSurface,
        ),
      ),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<ForgeActionItem>(
            key: ValueKey('forge.actionBar.overflow.${item.id}'),
            value: item,
            enabled: item.isEnabled,
            child: Row(
              children: [
                Icon(item.icon, size: iconSize),
                const SizedBox(width: 8),
                Expanded(child: Text(item.label)),
                if (item.shortcut != null) ...[
                  const SizedBox(width: 16),
                  Text(item.shortcut!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

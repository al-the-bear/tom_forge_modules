import 'package:flutter/material.dart';

import '../actions/status_bar_item.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import '../theme/forge_shell_theme.dart';

/// Status bar widget (~24px) at the bottom of the shell scaffold.
///
/// Reads [StatusBarItem]s from [ForgeStatusBarController] and
/// segments them left / center / right by alignment, sorted by priority.
/// When [systemState] is provided, items are filtered by their [StatusBarItem.isActive] callback.
class ForgeStatusBarWidget extends StatelessWidget {
  final ForgeStatusBarController controller;
  final ForgeSystemState? systemState;

  const ForgeStatusBarWidget({
    super.key,
    required this.controller,
    this.systemState,
  });

  @override
  Widget build(BuildContext context) {
    var items = controller.items;
    final state = systemState;
    if (state != null) {
      items = items.where((i) => i.isActive(state)).toList();
    }
    final leftItems = items
        .where((i) => i.alignment == StatusBarAlignment.left)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final centerItems = items
        .where((i) => i.alignment == StatusBarAlignment.center)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final rightItems = items
        .where((i) => i.alignment == StatusBarAlignment.right)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();

    return Container(
      height: 24,
      color: shellTheme?.statusBarBackground ?? theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final item in leftItems) _buildItem(context, item),
          const Spacer(),
          for (final item in centerItems) _buildItem(context, item),
          const Spacer(),
          for (final item in rightItems) _buildItem(context, item),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, StatusBarItem item) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: item.onTap,
      child: Tooltip(
        message: item.tooltip ?? '',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 12, color: color),
                const SizedBox(width: 2),
              ],
              ValueListenableBuilder<String>(
                valueListenable: item.text,
                builder: (context, text, _) {
                  return Text(
                    text,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

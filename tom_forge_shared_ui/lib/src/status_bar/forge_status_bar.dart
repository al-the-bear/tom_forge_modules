import 'package:flutter/material.dart';

import '../forge_dimensions.dart';
import '../forge_shell_theme.dart';
import 'forge_status_item.dart';

/// The status bar along the bottom of a Forge window or an application
/// beside it: [items] split into left, centre and right by their alignment,
/// higher priority first, with an inline [progressMessage] before the
/// centre items.
///
/// It rebuilds when an item's [ForgeStatusItem.visible] changes and when
/// [rebuild] notifies (e.g. the caller's list of items changed). The
/// background is [ForgeShellTheme.statusBarBackground], else the colour
/// scheme's primary colour.
class ForgeStatusBar extends StatelessWidget {
  const ForgeStatusBar({
    super.key,
    required this.items,
    this.rebuild,
    this.progressMessage,
  });

  final List<ForgeStatusItem> items;

  /// Notifies when [items] must be read again.
  final Listenable? rebuild;

  /// A progress message shown with a spinner; null: none.
  final String? progressMessage;

  @override
  Widget build(BuildContext context) {
    final visibility = [?rebuild, for (final item in items) ?item.visible];
    if (visibility.isEmpty) return _build(context);
    return ListenableBuilder(
      listenable: Listenable.merge(visibility),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final shown = items.where((i) => i.isVisible).toList();
    List<ForgeStatusItem> at(StatusBarAlignment alignment) =>
        shown.where((i) => i.alignment == alignment).toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));

    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();

    return Container(
      height: ForgeDimensions.statusBarHeight,
      color: shellTheme?.statusBarBackground ?? theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final item in at(StatusBarAlignment.left))
            _buildItem(context, item),
          const Spacer(),
          if (progressMessage != null) _buildProgressIndicator(context),
          for (final item in at(StatusBarAlignment.center))
            _buildItem(context, item),
          const Spacer(),
          for (final item in at(StatusBarAlignment.right))
            _buildItem(context, item),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimary;
    final mediaQuery = MediaQuery.maybeOf(context);
    final useStaticIndicator =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.highContrast ?? false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (useStaticIndicator)
            Icon(Icons.sync, size: 12, color: color)
          else
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            ),
          const SizedBox(width: 4),
          Text(
            progressMessage!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, ForgeStatusItem item) {
    final theme = Theme.of(context);
    final color = item.color ?? theme.colorScheme.onPrimary;
    final builder = item.builder;

    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: item.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Tooltip(
          message: item.tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: builder != null
                ? builder(context, color)
                : Row(
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
                              fontWeight: item.emphasis
                                  ? FontWeight.bold
                                  : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

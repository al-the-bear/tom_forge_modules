import 'dart:async';

import 'package:flutter/material.dart';

import '../actions/status_bar_item.dart';
import '../services/forge_progress_manager.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

/// Status bar widget (~24px) at the bottom of the shell scaffold.
///
/// Reads [StatusBarItem]s from [ForgeStatusBarController] and
/// segments them left / center / right by alignment, sorted by priority.
/// When [systemState] is provided, items are filtered by their
/// [StatusBarItem.isActive] callback and the widget rebuilds on
/// focus / editor / diagnostic changes.
///
/// When [progressManager] is provided, status-bar-targeted progress
/// events render an inline progress indicator.
class ForgeStatusBarWidget extends StatefulWidget {
  final ForgeStatusBarController controller;
  final ForgeSystemState? systemState;
  final ForgeProgressManager? progressManager;

  const ForgeStatusBarWidget({
    super.key,
    required this.controller,
    this.systemState,
    this.progressManager,
  });

  @override
  State<ForgeStatusBarWidget> createState() => _ForgeStatusBarWidgetState();
}

class _ForgeStatusBarWidgetState extends State<ForgeStatusBarWidget> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _progressMessage;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ForgeStatusBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.systemState != widget.systemState ||
        oldWidget.progressManager != widget.progressManager) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final state = widget.systemState;
    if (state != null) {
      _subscriptions.add(
        state.onFocusChanged.listen((_) {
          if (mounted) setState(() {});
        }),
      );
      _subscriptions.add(
        state.onEditorsChanged.listen((_) {
          if (mounted) setState(() {});
        }),
      );
      _subscriptions.add(
        state.onDiagnosticsChanged.listen((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    final progress = widget.progressManager;
    if (progress != null) {
      _subscriptions.add(
        progress.onProgress.listen((event) {
          if (mounted) {
            setState(() {
              _progressMessage =
                  event.message == 'Completed' || event.message == 'Failed'
                      ? null
                      : '${event.title}: ${event.message ?? '...'}';
            });
          }
        }),
      );
    }
  }

  void _unsubscribe() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  @override
  Widget build(BuildContext context) {
    var items = widget.controller.items;
    final state = widget.systemState;
    if (state != null) {
      items = items.where((i) => i.isActive(state)).toList();
    }
    final leftItems = items
        .where((i) => i.alignment == StatusBarAlignment.left)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final centerItems = items
        .where((i) => i.alignment == StatusBarAlignment.center)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final rightItems = items
        .where((i) => i.alignment == StatusBarAlignment.right)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

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
          if (_progressMessage != null) _buildProgressIndicator(context),
          for (final item in centerItems) _buildItem(context, item),
          const Spacer(),
          for (final item in rightItems) _buildItem(context, item),
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
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            ),
          const SizedBox(width: 4),
          Text(
            _progressMessage!,
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

  Widget _buildItem(BuildContext context, StatusBarItem item) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimary;

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
      ),
    );
  }
}

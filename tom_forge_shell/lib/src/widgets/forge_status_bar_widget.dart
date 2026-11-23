import 'dart:async';

import 'package:flutter/material.dart';

import '../actions/status_bar_item.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The shell's status bar: the adapter between the shell and the shared
/// [ForgeStatusBar].
///
/// Reads [StatusBarItem]s from [ForgeStatusBarController]. When
/// [systemState] is provided, items are filtered by their
/// [StatusBarItem.isActive] callback and the bar is rebuilt on
/// focus / editor / diagnostic changes; an item's own
/// [ForgeStatusItem.visible] is followed by the shared bar.
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
    return ForgeStatusBar(items: items, progressMessage: _progressMessage);
  }
}

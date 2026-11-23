import 'package:flutter/material.dart';

import '../actions/status_bar_item.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The shell's status bar: the adapter between the shell and the shared
/// [ForgeKitStatusBar].
///
/// Reads [StatusBarItem]s from [ForgeStatusBarController]. When
/// [systemState] is provided, items are filtered by their
/// [StatusBarItem.isActive] callback and the bar is rebuilt on
/// focus / editor / diagnostic changes (the kit state's events, followed by
/// the shared bar); an item's own [ForgeStatusItem.visible] is followed by
/// the shared bar.
///
/// When [progressManager] is provided, status-bar-targeted progress
/// events render an inline progress indicator.
class ForgeStatusBarWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final state = systemState;
    return ForgeKitStatusBar(
      state: state,
      progress: progressManager,
      // The shell's items draw more than the kit's model holds (colours,
      // widgets of their own) and apply by the shell's state.
      moreItems: () => state == null
          ? controller.items
          : controller.items.where((i) => i.isActive(state)).toList(),
    );
  }
}

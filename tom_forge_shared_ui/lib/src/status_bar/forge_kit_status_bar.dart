import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../forge_fixed_listenable.dart';
import 'forge_status_bar.dart';
import 'forge_status_item.dart';

/// The status bar over the kit: the [items] ([ForgeKitStatusItem]s) that
/// apply in [state] now (`isActive(state)`), drawn by [ForgeStatusBar], with
/// the inline progress of [progress].
///
/// It rebuilds when the kit state reports a change — the focus, the open
/// editors, the diagnostics — and when [rebuild] notifies. [moreItems] adds
/// items an application draws its own way (a colour, a widget of their own),
/// asked on every build; they come after the kit's items.
///
/// Without a [state] every item is shown and nothing is followed.
class ForgeKitStatusBar extends StatefulWidget {
  const ForgeKitStatusBar({
    super.key,
    this.state,
    this.items = const [],
    this.moreItems,
    this.progress,
    this.rebuild,
  });

  /// The status bar of [api]: its state and its progress.
  ForgeKitStatusBar.forApi({
    Key? key,
    required ForgeKitApi api,
    List<ForgeKitStatusItem> items = const [],
    List<ForgeStatusItem> Function()? moreItems,
    Listenable? rebuild,
  }) : this(
         key: key,
         state: api.state,
         items: items,
         moreItems: moreItems,
         progress: api.progress,
         rebuild: rebuild,
       );

  /// The kit state the items are asked about and followed; null: none.
  final ForgeKitState? state;

  /// The kit's status items.
  final List<ForgeKitStatusItem> items;

  /// Items drawn after the kit's, asked on every build.
  final List<ForgeStatusItem> Function()? moreItems;

  /// Status-bar progress, shown inline with a spinner while it runs.
  final ForgeProgressManager? progress;

  /// Notifies when the items must be read again.
  final Listenable? rebuild;

  /// The [ForgeStatusItem] that draws [item].
  static ForgeStatusItem statusItemOf(ForgeKitStatusItem item) =>
      ForgeStatusItem(
        text: ForgeFixedListenable<String>(item.text),
        icon: item.icon,
        alignment: item.alignment,
        priority: item.priority,
        onTap: item.onTap,
        tooltip: item.tooltip,
      );

  @override
  State<ForgeKitStatusBar> createState() => _ForgeKitStatusBarState();
}

class _ForgeKitStatusBarState extends State<ForgeKitStatusBar> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _progressMessage;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ForgeKitStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.progress != widget.progress) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _subscribe() {
    final state = widget.state;
    if (state != null) {
      _subscriptions
        ..add(state.onFocusChanged.listen((_) => _changed()))
        ..add(state.onEditorsChanged.listen((_) => _changed()))
        ..add(state.onDiagnosticsChanged.listen((_) => _changed()));
    }
    final progress = widget.progress;
    if (progress != null) {
      _subscriptions.add(
        progress.onProgress.listen((event) {
          if (!mounted) return;
          setState(() {
            _progressMessage =
                event.message == 'Completed' || event.message == 'Failed'
                ? null
                : '${event.title}: ${event.message ?? '...'}';
          });
        }),
      );
    }
  }

  void _unsubscribe() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final items = <ForgeStatusItem>[
      for (final item in widget.items)
        if (state == null || item.isActive(state))
          ForgeKitStatusBar.statusItemOf(item),
      ...?widget.moreItems?.call(),
    ];
    return ForgeStatusBar(
      items: items,
      rebuild: widget.rebuild,
      progressMessage: _progressMessage,
    );
  }
}

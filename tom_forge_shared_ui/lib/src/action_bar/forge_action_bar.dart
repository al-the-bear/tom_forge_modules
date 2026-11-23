import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../forge_dimensions.dart';
import '../forge_fixed_listenable.dart';
import 'forge_action_item.dart';

/// A row of icon buttons in groups — Forge's title-bar action bar, and any
/// row of actions an application beside Forge shows (Webwork's icon bar).
///
/// Each button follows its item's [ForgeActionItem.enabled]; groups are set
/// apart by a vertical divider. When the row is narrower than the buttons,
/// those that do not fit move into an overflow menu (a `more` button at the
/// end), in order; an unbounded row shows them all. An empty bar takes no
/// space.
///
/// It draws [ForgeActionItem]s the caller builds; [ForgeKitActionBar] draws
/// the kit's actions with it ([kitGroups]).
class ForgeActionBar extends StatelessWidget {
  const ForgeActionBar({
    super.key,
    required this.groups,
    this.iconSize = ForgeDimensions.iconToolbar,
  });

  /// The groups drawn.
  final List<ForgeActionGroup> groups;
  final double iconSize;

  /// The width of one button: the icon and its padding.
  double get buttonExtent => iconSize + 2 * _padding;

  /// The width of the divider between two groups.
  static const double dividerExtent = 9;

  static const double _padding = 4;

  /// The groups of the kit's [model] in [api] now, as the bar draws them:
  /// an action shows its icon (a puzzle piece when it has none), is enabled
  /// by [forgeActionEnabled], and runs through `api.executeAction`.
  static List<ForgeActionGroup> kitGroups(
    ForgeKitApi api,
    ForgeActionBarModel model,
  ) => [
    for (final (section, states) in model.resolve(api))
      ForgeActionGroup(
        id: section.id,
        items: [
          for (final state in states)
            ForgeActionItem(
              id: state.id,
              icon: state.icon ?? Icons.extension,
              label: state.label,
              shortcut: state.shortcut,
              enabled: ForgeFixedListenable<bool>(state.enabled),
              onInvoke: () => api.executeAction(state.id),
            ),
        ],
      ),
  ];

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

/// The action bar over the kit: the actions a [ForgeActionBarModel] names,
/// as [api]'s action registry and shortcut table have them
/// ([ForgeActionState]: label, icon, key, whether it can run), drawn by a
/// [ForgeActionBar]; a button runs its action through
/// [ForgeKitApi.executeAction].
///
/// It is kept current: rebuilt when the focus, the open editors, the active
/// editor's state, its unsaved state or the key bindings change.
class ForgeKitActionBar extends StatefulWidget {
  const ForgeKitActionBar({
    super.key,
    required this.api,
    required this.model,
    this.iconSize = ForgeDimensions.iconToolbar,
  });

  final ForgeKitApi api;

  /// Which actions the bar shows.
  final ForgeActionBarModel model;

  final double iconSize;

  @override
  State<ForgeKitActionBar> createState() => _ForgeKitActionBarState();
}

class _ForgeKitActionBarState extends State<ForgeKitActionBar> {
  final List<StreamSubscription<void>> _subscriptions = [];
  StreamSubscription<void>? _editorSubscription;
  ForgeEditor? _editor;
  Listenable? _bindings;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ForgeKitActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api)) {
      _unsubscribe();
      _subscribe();
    } else {
      _followEditor();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final state = widget.api.state;
    _subscriptions
      ..add(state.onFocusChanged.listen((_) => _changed()))
      ..add(state.onEditorsChanged.listen((_) => _changed()))
      ..add(state.onDirtyStateChanged.listen((_) => _changed()));
    _bindings = widget.api.shortcuts.onBindingsChanged..addListener(_changed);
    _followEditor();
  }

  void _unsubscribe() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _bindings?.removeListener(_changed);
    _bindings = null;
    _editorSubscription?.cancel();
    _editorSubscription = null;
    _editor = null;
  }

  /// Follows the active editor's state (what it can undo, copy, ...).
  void _followEditor() {
    final editor = widget.api.state.activeEditor;
    if (identical(editor, _editor)) return;
    _editorSubscription?.cancel();
    _editor = editor;
    _editorSubscription = editor?.onStateChanged.listen((_) => _changed());
  }

  void _changed() {
    if (!mounted) return;
    _followEditor();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ForgeActionBar(
      groups: ForgeActionBar.kitGroups(widget.api, widget.model),
      iconSize: widget.iconSize,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuEntry, ForgeContextTarget;
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeContextMenuController;

// The entry is data and lives in tom_forge_core; re-exported here so this
// library's users keep finding it where they did.
export 'package:tom_forge_core/tom_forge_core.dart' show ForgeContextMenuEntry;

/// The widget key of the menu entry for [id] — a contributed action's id or a
/// target item's own id: `forge-context-menu:<id>`.
Key forgeContextMenuEntryKey(String id) => Key('forge-context-menu:$id');

/// Draws [entries] as popup-menu items, in order, with a divider where the
/// group changes; a disabled entry carries its reason as a tooltip.
List<PopupMenuEntry<ForgeContextMenuEntry>> forgeContextMenuItems(
  List<ForgeContextMenuEntry> entries,
) {
  final items = <PopupMenuEntry<ForgeContextMenuEntry>>[];
  String? group;
  var first = true;
  for (final entry in entries) {
    if (!first && entry.group != null && entry.group != group) {
      items.add(const PopupMenuDivider());
    }
    if (entry.group != null) group = entry.group;
    first = false;
    final reason = entry.unavailableReason;
    items.add(
      PopupMenuItem<ForgeContextMenuEntry>(
        key: forgeContextMenuEntryKey(entry.id),
        value: entry,
        enabled: entry.enabled,
        height: 36,
        child: reason == null
            ? Text(entry.label)
            : Tooltip(message: reason, child: Text(entry.label)),
      ),
    );
  }
  return items;
}

/// Draws [entries] as a popup menu at [globalPosition] and runs the chosen
/// entry: in order, with a divider where the group changes, a disabled entry
/// showing its reason as a tooltip. Nothing is drawn for no entries.
Future<void> showForgeContextMenuEntries(
  BuildContext context, {
  required List<ForgeContextMenuEntry> entries,
  required Offset globalPosition,
}) async {
  if (entries.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final chosen = await showMenu<ForgeContextMenuEntry>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: forgeContextMenuItems(entries),
  );
  if (chosen == null) return;
  await chosen.run();
}

/// Draws the kit's context menu for [target] at [globalPosition] and runs the
/// chosen entry: the entries [controller] resolves at the target
/// ([ForgeContextMenuController.entriesFor]), drawn by
/// [showForgeContextMenuEntries]. Nothing is drawn when nothing applies at
/// the target.
Future<void> showForgeKitContextMenu(
  BuildContext context, {
  required ForgeContextMenuController controller,
  required ForgeContextTarget target,
  required Offset globalPosition,
}) => showForgeContextMenuEntries(
  context,
  entries: controller.entriesFor(target),
  globalPosition: globalPosition,
);

/// Makes [child]'s place the one that draws the kit's context menus: while
/// it is in the tree it is [controller]'s presenter, so a view or an editor
/// that calls `api.contextMenus.show(target, position)` gets the menu drawn
/// by [showForgeKitContextMenu]. When it leaves the tree it unbinds itself
/// (a presenter bound by someone else since is left alone).
class ForgeContextMenuPresenter extends StatefulWidget {
  const ForgeContextMenuPresenter({
    super.key,
    required this.controller,
    required this.child,
  });

  final ForgeContextMenuController controller;
  final Widget child;

  @override
  State<ForgeContextMenuPresenter> createState() =>
      _ForgeContextMenuPresenterState();
}

class _ForgeContextMenuPresenterState extends State<ForgeContextMenuPresenter> {
  @override
  void initState() {
    super.initState();
    widget.controller.presenter = _present;
  }

  @override
  void didUpdateWidget(ForgeContextMenuPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unbind(oldWidget.controller);
      widget.controller.presenter = _present;
    }
  }

  @override
  void dispose() {
    _unbind(widget.controller);
    super.dispose();
  }

  void _unbind(ForgeContextMenuController controller) {
    // Tear-offs of one method of one object are equal, not identical.
    if (controller.presenter == _present) controller.presenter = null;
  }

  Future<void> _present(ForgeContextTarget target, Offset globalPosition) {
    if (!mounted) return Future.value();
    return showForgeKitContextMenu(
      context,
      controller: widget.controller,
      target: target,
      globalPosition: globalPosition,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

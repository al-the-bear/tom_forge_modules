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

/// The widget key of the checkmark drawn on the checked entry [id]
/// ([ForgeContextMenuEntry.checked]): `forge-context-menu-check:<id>`.
Key forgeContextMenuCheckKey(String id) => Key('forge-context-menu-check:$id');

/// Where each submenu entry was drawn when it was chosen (its row, global),
/// for [runForgeContextMenuEntry] to show the submenu beside it.
final Expando<Rect> _submenuAnchors = Expando<Rect>('forge submenu anchor');

/// Draws [entries] as popup-menu items, in order, with a divider where the
/// group changes; a disabled entry carries its reason as a tooltip. A
/// checkable entry ([ForgeContextMenuEntry.checked]) is drawn with a
/// checkmark, or the room for one; a submenu entry
/// ([ForgeContextMenuEntry.hasChildren]) with an arrow, and choosing it
/// remembers where it was drawn so [runForgeContextMenuEntry] shows the
/// submenu beside it. Other entries are drawn as their label alone.
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
    final anchorKey = entry.hasChildren ? GlobalKey() : null;
    final label = entry.checked == null && anchorKey == null
        ? Text(entry.label)
        : _decoratedLabel(entry, anchorKey);
    items.add(
      PopupMenuItem<ForgeContextMenuEntry>(
        key: forgeContextMenuEntryKey(entry.id),
        value: entry,
        enabled: entry.enabled,
        height: 36,
        // Called right after the menu is popped, while the row is still laid
        // out: where the submenu goes.
        onTap: anchorKey == null
            ? null
            : () => _rememberAnchor(entry, anchorKey),
        child: reason == null ? label : Tooltip(message: reason, child: label),
      ),
    );
  }
  return items;
}

/// The label of a checkable or submenu entry: the checkmark's room, the
/// text, the submenu arrow at the row's end (a submenu's row spans the menu,
/// so its submenu goes beside the menu).
Widget _decoratedLabel(ForgeContextMenuEntry entry, GlobalKey? anchorKey) {
  final checked = entry.checked;
  final row = Row(
    mainAxisSize: anchorKey == null ? MainAxisSize.min : MainAxisSize.max,
    children: [
      if (checked != null) ...[
        SizedBox(
          width: 18,
          child: checked
              ? Icon(
                  Icons.check,
                  size: 16,
                  key: forgeContextMenuCheckKey(entry.id),
                )
              : null,
        ),
        const SizedBox(width: 8),
      ],
      if (anchorKey == null)
        Flexible(child: Text(entry.label))
      else ...[
        Expanded(child: Text(entry.label)),
        const SizedBox(width: 24),
        const Icon(Icons.arrow_right, size: 18),
      ],
    ],
  );
  return anchorKey == null
      ? row
      : SizedBox(key: anchorKey, width: double.infinity, child: row);
}

void _rememberAnchor(ForgeContextMenuEntry entry, GlobalKey anchorKey) {
  final box = anchorKey.currentContext?.findRenderObject();
  if (box is RenderBox && box.attached && box.hasSize) {
    final topLeft = box.localToGlobal(Offset.zero);
    _submenuAnchors[entry] = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      box.size.width,
      box.size.height,
    );
  }
}

/// Runs [entry], chosen from a menu drawn at [globalPosition]: an entry that
/// runs is run; a submenu entry ([ForgeContextMenuEntry.hasChildren]) shows
/// its children as a menu beside the row it was drawn in — to its right, or
/// to its left near the right edge — (at [globalPosition] when that is not
/// known) and runs the one chosen there, a submenu again in the same way.
/// For a surface that draws its own menu with [forgeContextMenuItems] among
/// its items.
Future<void> runForgeContextMenuEntry(
  BuildContext context,
  ForgeContextMenuEntry entry, {
  required Offset globalPosition,
}) async {
  if (!entry.hasChildren) {
    await entry.run();
    return;
  }
  final anchor = _submenuAnchors[entry];
  _submenuAnchors[entry] = null;
  if (!context.mounted) return;
  await _showEntries(
    context,
    entries: entry.children,
    globalPosition: globalPosition,
    position: anchor == null
        ? null
        : (overlay) => _besideAnchor(anchor, overlay),
  );
}

/// The smallest room right of a submenu's row the submenu is drawn in; with
/// less it is drawn left of the menu.
const double _submenuRoom = 220;

/// Where a submenu of the row [anchor] goes: its left edge at the row's
/// right, or its right edge at the row's left when the overlay has no room
/// on the right ([showMenu] grows towards the side whose distance is
/// smaller).
RelativeRect _besideAnchor(Rect anchor, Size overlay) {
  if (anchor.right + _submenuRoom <= overlay.width) {
    return RelativeRect.fromLTRB(
      anchor.right,
      anchor.top,
      overlay.width,
      overlay.height - anchor.top,
    );
  }
  return RelativeRect.fromLTRB(
    overlay.width,
    anchor.top,
    overlay.width - anchor.left,
    overlay.height - anchor.top,
  );
}

/// Draws [entries] as a popup menu at [globalPosition] and runs the chosen
/// entry: in order, with a divider where the group changes, a disabled entry
/// showing its reason as a tooltip, a submenu entry opening its submenu
/// ([runForgeContextMenuEntry]). Nothing is drawn for no entries.
Future<void> showForgeContextMenuEntries(
  BuildContext context, {
  required List<ForgeContextMenuEntry> entries,
  required Offset globalPosition,
}) => _showEntries(context, entries: entries, globalPosition: globalPosition);

Future<void> _showEntries(
  BuildContext context, {
  required List<ForgeContextMenuEntry> entries,
  required Offset globalPosition,
  RelativeRect Function(Size overlay)? position,
}) async {
  if (entries.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final chosen = await showMenu<ForgeContextMenuEntry>(
    context: context,
    position:
        position?.call(overlay.size) ??
        RelativeRect.fromRect(
          globalPosition & const Size(1, 1),
          Offset.zero & overlay.size,
        ),
    items: forgeContextMenuItems(entries),
  );
  if (chosen == null) return;
  if (!chosen.hasChildren) {
    await chosen.run();
    return;
  }
  if (!context.mounted) return;
  await runForgeContextMenuEntry(
    context,
    chosen,
    globalPosition: globalPosition,
  );
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

import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../shell/forge_context_menu_controller.dart';

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
    items.add(PopupMenuItem<ForgeContextMenuEntry>(
      key: forgeContextMenuEntryKey(entry.id),
      value: entry,
      enabled: entry.enabled,
      height: 36,
      child: reason == null
          ? Text(entry.label)
          : Tooltip(message: reason, child: Text(entry.label)),
    ));
  }
  return items;
}

/// Draws the context menu for [target] at [globalPosition] and runs the
/// chosen entry. Nothing is drawn when nothing applies at the target.
Future<void> showForgeContextMenu(
  BuildContext context, {
  required ForgeContextMenuController controller,
  required ForgeContextTarget target,
  required Offset globalPosition,
}) async {
  final entries = controller.entriesFor(target);
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

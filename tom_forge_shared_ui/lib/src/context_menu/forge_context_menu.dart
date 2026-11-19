import 'package:flutter/material.dart';

/// One entry of a context menu: in Forge a module contribution resolved
/// against its action, or an item the target brought of its own; in an
/// application beside Forge, any entry it builds.
class ForgeContextMenuEntry {
  const ForgeContextMenuEntry({
    required this.id,
    required this.label,
    required this.enabled,
    required this.run,
    this.unavailableReason,
    this.group,
  });

  /// The action id of a contribution, or the item's own id.
  final String id;

  final String label;

  final bool enabled;

  /// Shown as the disabled entry's tooltip.
  final String? unavailableReason;

  /// A divider is drawn where it changes.
  final String? group;

  final Future<void> Function() run;
}

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

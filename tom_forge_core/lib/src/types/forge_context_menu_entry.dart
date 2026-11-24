/// One entry of a context menu, as data: in Forge a module contribution
/// resolved against its action, or an item the target brought of its own; in
/// an application beside Forge, any entry it builds. Drawing it is the
/// application's (`tom_forge_shared_ui` draws it as a popup-menu item).
///
/// An entry with [children] is a submenu (**Open With ▸**): choosing it
/// shows the children instead of running [run]. An entry whose [checked] is
/// non-null is a checkable one, drawn with a checkmark when true.
class ForgeContextMenuEntry {
  const ForgeContextMenuEntry({
    required this.id,
    required this.label,
    required this.enabled,
    required this.run,
    this.unavailableReason,
    this.group,
    this.children = const [],
    this.checked,
  });

  /// The action id of a contribution, or the item's own id.
  final String id;

  final String label;

  final bool enabled;

  /// Shown as the disabled entry's tooltip.
  final String? unavailableReason;

  /// A divider is drawn where it changes.
  final String? group;

  /// Runs the entry; a submenu's ([hasChildren]) is not run when chosen.
  final Future<void> Function() run;

  /// The entries of the submenu this entry opens, in order (dividers where
  /// their [group] changes); empty for an entry that runs.
  final List<ForgeContextMenuEntry> children;

  /// Whether the entry shows a checkmark (true) or the room for one (false);
  /// null for an entry that is not checkable.
  final bool? checked;

  /// Whether the entry opens a submenu ([children]).
  bool get hasChildren => children.isNotEmpty;
}

/// One entry of a context menu, as data: in Forge a module contribution
/// resolved against its action, or an item the target brought of its own; in
/// an application beside Forge, any entry it builds. Drawing it is the
/// application's (`tom_forge_shared_ui` draws it as a popup-menu item).
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

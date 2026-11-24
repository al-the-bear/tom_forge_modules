import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../model/forge_application.dart';

/// The panel the panel shell shows a contributed view of [role] in: the
/// views to find and choose what to work on on the left, the details of
/// what the user works on on the right, what the application reports at the
/// bottom.
ForgePanelLocation forgePanelLocationOf(ForgeViewRole role) => switch (role) {
  ForgeViewRole.navigation => ForgePanelLocation.left,
  ForgeViewRole.details => ForgePanelLocation.right,
  ForgeViewRole.messages => ForgePanelLocation.bottom,
};

/// The tabs of the side or bottom panel [location], made from the views the
/// modules of [registry] contribute with a placement hint
/// ([forgeContributedViews]) whose role the shell shows there
/// ([forgePanelLocationOf]): one tab per hint group, titled by the group
/// (else the view's title) with the group's icon (else the first view's),
/// its sections the group's views; tabs and sections ordered by the hints'
/// order (a group by its first view), the registration order breaking ties.
///
/// The shell names no view: an application lays its panels out from these
/// tabs, adds its own beside them or leaves them out. Views without a hint
/// are not placed. Empty when no module contributes a view for [location];
/// the lists are growable, as the scaffold edits a layout's tabs in place.
List<PanelTabConfig> forgeContributedPanelTabs(
  ForgeKitModuleRegistry registry,
  ForgePanelLocation location,
) {
  final placed = [
    for (final contributed in forgeContributedViews(registry))
      if (contributed.hint case final hint?
          when forgePanelLocationOf(hint.role) == location)
        (view: contributed.view, hint: hint),
  ];
  final indexed =
      [for (var i = 0; i < placed.length; i++) (index: i, entry: placed[i])]
        ..sort((a, b) {
          final byOrder = a.entry.hint.order.compareTo(b.entry.hint.order);
          return byOrder != 0 ? byOrder : a.index.compareTo(b.index);
        });
  final groups =
      <String, List<({ForgeView view, ForgeViewPlacementHint hint})>>{};
  for (final item in indexed) {
    final entry = item.entry;
    final group = entry.hint.group ?? entry.view.title.value;
    groups.putIfAbsent(group, () => []).add(entry);
  }
  return [
    for (final MapEntry(key: title, value: entries) in groups.entries)
      PanelTabConfig(
        title: title,
        icon:
            entries
                .map((e) => e.hint.groupIcon)
                .firstWhere((icon) => icon != null, orElse: () => null) ??
            entries.first.view.icon,
        sections: [for (final entry in entries) entry.view],
      ),
  ];
}

/// A panel layout made from the contributed views alone
/// ([forgeContributedPanelTabs] for the left, right and bottom panels) with
/// [middlePanels]: what an application shows when it lays out nothing but
/// the views its modules contribute. With no view contributed every side
/// panel is empty, and the shell still starts.
PanelLayout forgeContributedPanelLayout(
  ForgeKitModuleRegistry registry, {
  double leftSize = 250,
  double rightSize = 220,
  double bottomSize = 180,
  List<MiddlePanelConfig> middlePanels = const [MiddlePanelConfig()],
}) => PanelLayout(
  leftPanel: PanelConfig(
    initialSize: leftSize,
    tabs: forgeContributedPanelTabs(registry, ForgePanelLocation.left),
  ),
  rightPanel: PanelConfig(
    initialSize: rightSize,
    tabs: forgeContributedPanelTabs(registry, ForgePanelLocation.right),
  ),
  bottomPanel: PanelConfig(
    initialSize: bottomSize,
    tabs: forgeContributedPanelTabs(registry, ForgePanelLocation.bottom),
  ),
  middlePanels: [...middlePanels],
);

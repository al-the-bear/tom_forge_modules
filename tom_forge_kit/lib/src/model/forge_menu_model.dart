import '../actions/forge_action.dart';
import '../kit/forge_kit_api.dart';
import 'forge_action_state.dart';

/// One entry of a [ForgeMenuModel]: an action or a separator.
sealed class ForgeMenuModelEntry {
  const ForgeMenuModelEntry();
}

/// A menu entry that runs an action (`api.executeAction(action.id)`).
final class ForgeMenuActionEntry extends ForgeMenuModelEntry {
  const ForgeMenuActionEntry(this.action);

  final ForgeActionState action;
}

/// A separator between two groups of a menu.
final class ForgeMenuSeparatorEntry extends ForgeMenuModelEntry {
  const ForgeMenuSeparatorEntry();
}

/// A menu as data: the visible actions of the kit's action registry placed
/// at one [ForgeMenuLocation] (File, Edit, View, ...), by group, with a
/// separator between two groups.
///
/// The groups come in the order their first action was registered (the
/// actions of no group first); within a group the actions are ordered by
/// `ForgeAction.priority` (lower first), then by registration. Where the
/// menu is drawn — a menu bar, a button, a native menu — is the
/// application's.
class ForgeMenuModel {
  const ForgeMenuModel({required this.location, required this.entries});

  /// The menu of [location] in [api] now.
  factory ForgeMenuModel.of(ForgeKitApi api, ForgeMenuLocation location) {
    final groups = <String?, List<ForgeAction>>{null: []};
    for (final action in api.actionRegistry.allActions) {
      if (action.menu != location || !action.isVisible()) continue;
      groups.putIfAbsent(action.group, () => []).add(action);
    }
    final entries = <ForgeMenuModelEntry>[];
    for (final actions in groups.values) {
      if (actions.isEmpty) continue;
      final ordered = [for (var i = 0; i < actions.length; i++) (i, actions[i])]
        ..sort((a, b) {
          final byPriority = a.$2.priority.compareTo(b.$2.priority);
          return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
        });
      if (entries.isNotEmpty) entries.add(const ForgeMenuSeparatorEntry());
      for (final (_, action) in ordered) {
        entries.add(
          ForgeMenuActionEntry(ForgeActionState.ofAction(api, action)),
        );
      }
    }
    return ForgeMenuModel(location: location, entries: entries);
  }

  final ForgeMenuLocation location;

  final List<ForgeMenuModelEntry> entries;

  /// Whether the menu has no action.
  bool get isEmpty => entries.isEmpty;

  /// The menu's title as a menu bar shows it (`File`, `Edit`, ...).
  String get title => forgeMenuTitle(location);
}

/// The title of the menu at [location]: `File`, `Edit`, `View`, `Go`, `Run`,
/// `Tools`, `Help`; `Context Menu` and `Commands` for the two places that are
/// no menu of a menu bar.
String forgeMenuTitle(ForgeMenuLocation location) => switch (location) {
  ForgeMenuLocation.file => 'File',
  ForgeMenuLocation.edit => 'Edit',
  ForgeMenuLocation.view => 'View',
  ForgeMenuLocation.go => 'Go',
  ForgeMenuLocation.run => 'Run',
  ForgeMenuLocation.tools => 'Tools',
  ForgeMenuLocation.help => 'Help',
  ForgeMenuLocation.contextMenu => 'Context Menu',
  ForgeMenuLocation.commandPalette => 'Commands',
};

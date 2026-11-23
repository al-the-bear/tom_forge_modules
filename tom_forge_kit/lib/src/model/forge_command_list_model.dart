import '../kit/forge_kit_api.dart';
import 'forge_action_state.dart';

/// The kit's actions as a list to choose from — a command palette, a dialog,
/// a side area: every visible action of the action registry, by label,
/// narrowed by a [query].
class ForgeCommandListModel {
  const ForgeCommandListModel({required this.query, required this.commands});

  /// The visible actions of [api] now whose label or id contains [query]
  /// (any case; every visible action for an empty query), ordered by label.
  factory ForgeCommandListModel.of(ForgeKitApi api, {String query = ''}) {
    final needle = query.trim().toLowerCase();
    final commands =
        [
          for (final action in api.actionRegistry.allActions)
            if (action.isVisible() &&
                (needle.isEmpty ||
                    action.label.toLowerCase().contains(needle) ||
                    action.id.toLowerCase().contains(needle)))
              ForgeActionState.ofAction(api, action),
        ]..sort((a, b) {
          final byLabel = a.label.toLowerCase().compareTo(
            b.label.toLowerCase(),
          );
          return byLabel != 0 ? byLabel : a.id.compareTo(b.id);
        });
    return ForgeCommandListModel(query: query, commands: commands);
  }

  /// The text the list is narrowed by.
  final String query;

  /// The commands, in the order they are shown.
  final List<ForgeActionState> commands;
}

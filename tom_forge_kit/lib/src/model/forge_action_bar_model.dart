import '../kit/forge_kit_api.dart';
import 'forge_action_state.dart';

/// One group of an action bar: the ids of the actions it shows, in order.
class ForgeActionBarSection {
  const ForgeActionBarSection({required this.id, required this.actionIds});

  final String id;

  /// The action ids, in the order they are shown.
  final List<String> actionIds;
}

/// Which actions an action bar shows: its [sections] (groups set apart from
/// each other), each a list of action ids. The actions themselves — label,
/// icon, key, whether they can run — come from the kit ([resolve]).
class ForgeActionBarModel {
  const ForgeActionBarModel({required this.sections});

  /// One section of [actionIds].
  ForgeActionBarModel.of(
    List<String> actionIds, {
    String id = 'forge.actionBar',
  }) : sections = [ForgeActionBarSection(id: id, actionIds: actionIds)];

  final List<ForgeActionBarSection> sections;

  /// The sections with the state of their actions in [api] now: an id no
  /// action is registered for, or an action not visible now, is left out.
  /// A section may come out empty.
  List<(ForgeActionBarSection, List<ForgeActionState>)> resolve(
    ForgeKitApi api,
  ) => [
    for (final section in sections)
      (
        section,
        [
          for (final id in section.actionIds)
            if (ForgeActionState.of(api, id) case final state?)
              if (state.visible) state,
        ],
      ),
  ];
}

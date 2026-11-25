import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../quest_catalogue.dart';
import '../quests_trail.dart';
import 'forge_quest_view.dart';

/// The id of the quest view ([ForgeViewPlacementHint.id]).
const String forgeQuestViewId = 'forge.view.quest';

/// Where the quest view goes unless the application says otherwise: with the
/// messages (the panel shell: the bottom panel), as the VS Code extension's
/// Logs panel is, in a Quest group.
const ForgeViewPlacementHint forgeQuestViewPlacement = ForgeViewPlacementHint(
  id: forgeQuestViewId,
  role: ForgeViewRole.messages,
  group: 'Quest',
  groupIcon: Icons.flag_outlined,
);

/// Contributes the quest view ([ForgeQuestView]) of one quest to any
/// application on the kit: made at activation over the application's API
/// ([ForgeQuestView.forApi]), listed in [views], placed by its
/// [ForgeViewContributionsExtra] with [placement].
///
/// The quest is [questFolder] (absolute) when given, else the folder of
/// [quest] under the workspace's `_ai/quests/` ([forgeQuestsFolder]), the
/// workspace being the application state's [ForgeWorkspaceRoot].
class ForgeQuestViewModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeQuestViewModule({
    this.questFolder,
    this.quest,
    this.placement = forgeQuestViewPlacement,
    this.pollInterval = const Duration(seconds: 2),
    this.watch = false,
  }) : assert(
         questFolder != null || quest != null,
         'a quest view needs the quest folder or the quest id',
       );

  /// The quest folder, absolute; null takes [quest] under the workspace.
  final String? questFolder;

  /// The quest id, its folder under the workspace's `_ai/quests/`.
  final String? quest;

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  /// The view's [ForgeQuestView.pollInterval].
  final Duration pollInterval;

  /// The view's [ForgeQuestView.watch].
  final bool watch;

  ForgeQuestView? _view;

  /// The view, once activated.
  ForgeQuestView? get view => _view;

  @override
  String get displayName => 'Quest view';

  /// The quest folder over [api]: [questFolder], else [quest] under the
  /// workspace root of [api]'s state.
  String folderFor(ForgeKitApi api) {
    if (questFolder case final folder?) return p.normalize(folder);
    if (api.state case final ForgeWorkspaceRoot root) {
      return p.normalize(
        p.join(root.workspaceRootPath, forgeQuestsFolder, quest!),
      );
    }
    throw StateError(
      'ForgeQuestViewModule: quest "$quest" needs a workspace root (the '
      'application state is no ForgeWorkspaceRoot); give questFolder',
    );
  }

  @override
  void activate(ForgeKitApi api) {
    final folder = folderFor(api);
    _view = ForgeQuestView.forApi(
      api,
      quest: folder,
      pollInterval: pollInterval,
      watch: watch,
    );
    questsTrailEvent('quest view module activated over $folder');
  }

  @override
  void deactivate() {
    _view = null;
    questsTrailEvent('quest view module deactivated');
  }

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => [?_view];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => [
    if (_view case final view?)
      ForgeViewContributionsExtra([
        ForgeViewContribution(view: view, hint: placement),
      ]),
  ];
}

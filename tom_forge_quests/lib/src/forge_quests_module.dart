import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show ForgeApplication, ForgeModule, ForgeShellApi;

import 'quest_application.dart';
import 'quest_catalogue.dart';
import 'quests_trail.dart';

/// The id of the action that offers the quest picker.
const forgeOpenQuestActionId = 'forge.quest.open';

/// The quest applications in a Forge shell: activating the module registers
/// the [questApplicationKind] factory, so the quest applications open at the
/// last exit come back through `restoreApplications`, and the Open Quest
/// action ([forgeOpenQuestActionId]), the picker over the workspace's
/// `_ai/quests/`. A module action is the shell's in every application, so
/// the picker is there in the tom_forge application and in every quest
/// application alike.
class ForgeQuestsModule extends ForgeModule {
  ForgeShellApi? _shell;

  late final List<ForgeAction> _actions = [
    ForgeAction(
      id: forgeOpenQuestActionId,
      label: 'Open Quest…',
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        await pickQuest();
        return null;
      },
      isEnabled: () => _shell != null,
      isVisible: () => true,
    ),
  ];

  @override
  String get displayName => 'Quests';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    final applications = shell.applications;
    // Once per shell: a factory cannot be registered twice, and a module
    // activated again on the same shell finds its own there.
    if (!applications.hasFactory(questApplicationKind)) {
      applications.registerFactory(ForgeQuestApplicationFactory());
    }
    questsTrailEvent('activated');
  }

  @override
  void deactivate() {
    _shell = null;
    questsTrailEvent('deactivated');
  }

  ForgeShellApi get _activeShell =>
      _shell ?? (throw StateError('ForgeQuestsModule is not active'));

  /// The quests of the shell's workspace, by id.
  Future<List<String>> quests() {
    final shell = _activeShell;
    return listForgeQuests(
      shell.fileSystem,
      shell.systemState.workspaceRootPath,
    );
  }

  /// The open application of [quest], or null.
  ForgeApplication? applicationOf(String quest) => _activeShell.applications.all
      .where((application) => questOf(application) == quest)
      .firstOrNull;

  /// Shows the quest picker — every quest of the workspace, those already
  /// open marked so — and opens the one picked ([openQuest]). Answers it, or
  /// null when none was picked; a workspace without quests says so.
  Future<ForgeApplication?> pickQuest() async {
    final shell = _activeShell;
    final ids = await quests();
    if (ids.isEmpty) {
      shell.notifications.showInformation(
        'This workspace has no quests: there is no $forgeQuestsFolder folder '
        'with a quest in it.',
      );
      return null;
    }
    final picked = await shell.dialogs.showQuickPick<String>([
      for (final id in ids)
        ForgeQuickPickItem(
          label: id,
          value: id,
          description: applicationOf(id) == null ? null : 'open',
        ),
    ], placeholder: 'Open a quest');
    questsTrailEvent('picked ${picked ?? '(none)'}');
    return picked == null ? null : openQuest(picked);
  }

  /// The application of [quest], activated: the open one when there is one
  /// (at most one application per quest), else a new one titled by the quest.
  ForgeApplication openQuest(String quest) {
    final applications = _activeShell.applications;
    final open = applicationOf(quest);
    if (open != null) {
      applications.activate(open.id);
      return open;
    }
    return applications.open(
      questApplicationKind,
      title: quest,
      payload: {questPayloadKey: quest},
    );
  }

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => _actions;

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

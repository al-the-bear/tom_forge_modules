import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'quests_trail.dart';

/// The application kind of a quest application, in the registry and in
/// `.forge/state/applications.json`.
const questApplicationKind = 'quest';

/// The payload key holding the quest id of a quest application.
const questPayloadKey = 'quest';

/// The quest a quest application shows, or null for any other application.
String? questOf(ForgeApplication application) =>
    application.kind == questApplicationKind
    ? application.payload[questPayloadKey] as String?
    : null;

/// The containers of a quest application's frame: where the quest runtime's
/// views go.
enum ForgeQuestContainer {
  /// @TOM, on the left: the quest's own views (todos, process, notes).
  tom('@TOM', Icons.flag_outlined, 'Quest views'),

  /// @TOM WS, on the left: the workspace as the quest sees it.
  tomWorkspace('@TOM WS', Icons.workspaces_outline, 'Workspace views'),

  /// @CHAT, at the bottom: the quest's chat and its prompt queue.
  chat('@CHAT', Icons.chat_bubble_outline, 'Chat'),

  /// @WS, at the bottom: the workspace's shared views (trail, output).
  workspace('@WS', Icons.terminal, 'Workspace output');

  const ForgeQuestContainer(this.label, this.icon, this.what);

  /// The tab's title.
  final String label;

  final IconData icon;

  /// What the runtime's views there show, for the placeholder.
  final String what;
}

/// Makes the quest applications: one [ForgeApplication] of kind
/// [questApplicationKind] per quest, its payload `{'quest': <id>}`, titled by
/// the registry's caller (the quest id). The frame is a [PanelLayout]: @TOM
/// and @TOM WS as the left panel's tabs, one middle group for editors, @CHAT
/// and @WS as the bottom panel's tabs — each holding a
/// [ForgeQuestPlaceholderView] until the quest runtime's views take its
/// place. At most one application per quest is the opener's rule
/// (`ForgeQuestsModule.openQuest`); the factory makes what it is asked for,
/// as a restore needs.
class ForgeQuestApplicationFactory implements ForgeApplicationFactory {
  @override
  String get kind => questApplicationKind;

  @override
  ForgeApplication create(ForgeApplicationContext context, String title) {
    final quest = context.payload[questPayloadKey];
    if (quest is! String || quest.isEmpty) {
      throw ArgumentError.value(
        context.payload,
        'payload',
        'a quest application needs {"$questPayloadKey": <quest id>}',
      );
    }
    questsTrailEvent('create ${context.id} for quest "$quest"');
    PanelTabConfig tab(ForgeQuestContainer container) => PanelTabConfig(
      title: container.label,
      icon: container.icon,
      sections: [ForgeQuestPlaceholderView(quest, container)],
    );
    return ForgeApplication(
      id: context.id,
      title: title,
      icon: Icons.flag,
      kind: kind,
      payload: context.payload,
      lifecycle: ForgeQuestApplicationLifecycle(quest),
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 280,
          tabs: [
            tab(ForgeQuestContainer.tom),
            tab(ForgeQuestContainer.tomWorkspace),
          ],
        ),
        bottomPanel: PanelConfig(
          initialSize: 220,
          tabs: [
            tab(ForgeQuestContainer.chat),
            tab(ForgeQuestContainer.workspace),
          ],
        ),
        middlePanels: const [MiddlePanelConfig()],
      ),
    );
  }
}

/// The lifecycle of a quest application. What it reports is what the quest
/// runtime running for the quest sets: [backgroundWork] while its queue or
/// timers run (the application's state is then never evicted), [busyLabel]
/// as the switcher's badge, and while busy a close — and a quit (Forge asks
/// every application's `closing`) — is vetoed with what it is busy with.
/// Before a runtime is connected both stay unset, and the application closes
/// unasked.
class ForgeQuestApplicationLifecycle extends ForgeApplicationLifecycle {
  ForgeQuestApplicationLifecycle(this.quest);

  /// The quest the application shows.
  final String quest;

  /// Whether the quest runtime has work running while the application is not
  /// shown.
  final ValueNotifier<bool> backgroundWork = ValueNotifier(false);

  /// What the quest runtime is busy with (e.g. "Queue sending 3 prompts"), or
  /// null when idle.
  final ValueNotifier<String?> busyLabel = ValueNotifier(null);

  @override
  ValueListenable<bool> get hasBackgroundWork => backgroundWork;

  @override
  ValueListenable<String?> get busy => busyLabel;

  @override
  Future<String?> closing(ForgeApplication application) async {
    final label = busyLabel.value;
    questsTrailEvent('closing ${application.id}: ${label ?? 'idle'}');
    return label == null
        ? null
        : 'The quest runtime of $quest is still busy: $label.';
  }

  @override
  void activated(ForgeApplication application) =>
      questsTrailEvent('activated ${application.id} ($quest)');

  @override
  void closed(ForgeApplication application) {
    questsTrailEvent('closed ${application.id} ($quest)');
  }
}

/// What a container of the quest application frame shows until the quest
/// runtime's views are there: the container, the quest, and that the runtime
/// is not connected yet.
class ForgeQuestPlaceholderView extends ForgeView {
  ForgeQuestPlaceholderView(this.quest, this.container)
    : title = ValueNotifier(container.label);

  final String quest;
  final ForgeQuestContainer container;

  @override
  final ValueListenable<String> title;

  @override
  final ValueListenable<String?> titleExtension = ValueNotifier(null);

  @override
  IconData get icon => container.icon;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('forge.quest.placeholder.${container.name}.$quest'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${container.label} — ${container.what} of $quest',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'The quest runtime is not connected yet.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

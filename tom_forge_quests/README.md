# Tom Forge Quests

The quest applications of Tom Forge: one Forge application per open quest,
beside the tom_forge application. Every app built on Forge's suite has them
(`composeForgeSuite` registers `ForgeQuestsModule` as `suite.questsModule`):
Tom Forge itself and Webforge.

This package is the frame the quest runtime's views fill. The runtime — the
VS Code extension's engine as a process, one per open quest — and the views
over it come later; until then each container says the runtime is not
connected yet.

## What is here

- **The quests.** A quest is a folder under the workspace's `_ai/quests/`
  (`listForgeQuests`), the rule the VS Code extension's quest list follows:
  files beside them and hidden folders are not quests.
- **The picker.** `ForgeQuestsModule` contributes the File menu's
  **Open Quest…** (`forgeOpenQuestActionId`), a quick pick over the quests
  with the open ones marked. A module action is the shell's in every
  application, so the picker is there in the tom_forge application and in
  every quest application.
- **One application per quest.** `ForgeQuestsModule.openQuest(id)` activates
  the quest's application when it is open and opens one otherwise: kind
  `quest` (`questApplicationKind`), payload `{'quest': <id>}`, titled by the
  quest. `questOf(application)` answers the quest an application shows.
- **The frame.** `ForgeQuestApplicationFactory` lays a quest application out
  as a panel application: **@TOM** and **@TOM WS** as the left panel's tabs,
  one editor group in the middle, **@CHAT** and **@WS** as the bottom panel's
  tabs (`ForgeQuestContainer`), each holding a `ForgeQuestPlaceholderView`.
- **The lifecycle.** `ForgeQuestApplicationLifecycle` reports what the
  runtime sets: `backgroundWork` (the application's state is then never
  evicted) and `busyLabel` (the switcher's badge). While busy, closing the
  application — and quitting Forge, which asks every application — is vetoed
  with what it is busy with.
- **Restart.** The factory is registered before the suite restores the
  applications open at the last exit, so the quest applications come back,
  each with the layout it had (`.forge/state/apps/`).

## Use

```dart
final suite = await composeForgeSuite(shell: shell, workspaceRoot: root);
final application = suite.questsModule.openQuest('tom_forge');
```

A host without the suite registers the module itself, before it restores the
applications:

```dart
final quests = ForgeQuestsModule();
quests.activate(shell);
(shell.modules as DefaultModuleRegistry).register(quests);
await shell.restoreApplications();
```

## Debug mode

`lib/src/quests_trail.dart` holds the debug switch `kForgeQuestsDebug`; when
true, the picker, opens, activations and lifecycle events are traced with the
`[FQ` prefix (`flutter run 2>&1 | grep '\[FQ'`).

## Licence

BSD-3-Clause, like every Forge package — see [LICENSE](LICENSE).

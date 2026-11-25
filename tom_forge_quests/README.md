# Tom Forge Quests

The quest applications of Tom Forge: one Forge application per open quest,
beside the tom_forge application; and the quest view, a kit view over a
quest folder's AI files. Every app built on Forge's suite has them
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

- **The quest view.** `ForgeQuestView` shows a quest folder's AI files as
  the VS Code extension's Logs panel does: the tabs MD Trail, Trail, Prompts,
  Answers, Progress, Overview, Notes, Refresh, DocUpdate, Deferred,
  Questions, Decisions, Current Prompt and Todos, with the session selector
  for the trail and the history pair (`chat`, `default`, every session with
  a file, the extension's single-file shape) and the variant selector for
  Current Prompt (read from the trail bucket `_ai/trail/anthropic/<q>/`).
  Which file each tab shows is `forgeQuestLogFile` (`forge_quest_files.dart`,
  pure). A tab reads only the newest 256 KiB of its file
  (`forgeQuestLogMaxBytes`), from the end the file grows at (the trail and the
  journals from their end), and says so when it shows less than the file; a
  missing file is said, not hidden. The view looks again every
  `pollInterval` (2 s), whenever the application's file system reports a
  change in the quest folder or the bucket (`TomFileSystem.onDidChange`), and,
  with `watch: true`, whenever its watch does; it re-reads a file only when
  its size or modification time moved. *Open file* and a todo picked in
  Todos open through the kit (`forgeOpenFileAtOf`: the application's
  `ForgeFileNavigator`, else `ForgeKitApi.openFile`); Todos is `tom_todo_ui`'s
  aggregate over the quest folder (`ForgeQuestTodoSource` over
  `ForgeFolderFileSystem`, the application's file system seen from the quest
  folder).
- **The quest view module.** `ForgeQuestViewModule` contributes the view of
  one quest (`questFolder`, or `quest` under the workspace root of the
  application state's `ForgeWorkspaceRoot`) to any application on the kit,
  with the placement hint `forgeQuestViewPlacement` (id `forge.view.quest`,
  role messages, group Quest), so the application places it by its hint or
  finds it with `forgeContributedViewById`. The quest applications' frame is
  unchanged: it still holds the placeholder views.

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

The quest view in an application on the kit:

```dart
api.registerModule(ForgeQuestViewModule(quest: 'tom_forge'));
final view = forgeContributedViewById(api.modules, forgeQuestViewId);
// or directly:
final questView = ForgeQuestView.forApi(api, quest: '/ws/_ai/quests/tom_forge');
```

## Debug mode

`lib/src/quests_trail.dart` holds the debug switch `kForgeQuestsDebug`; when
true, the picker, opens, activations and lifecycle events, and the quest
view's tabs, sessions, reads and opens are traced with the `[FQ` prefix
(`flutter run 2>&1 | grep '\[FQ'`).

## Licence

BSD-3-Clause, like every Forge package — see [LICENSE](LICENSE).

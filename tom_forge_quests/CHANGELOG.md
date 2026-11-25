# Changelog

## 0.2.0

- The quest view as a kit view: `ForgeQuestView` (with `.forApi`) over a
  quest folder's AI files — the VS Code extension's Logs panel tabs with the
  session and Current Prompt selectors, the newest 256 KiB of each file read
  from the end it grows at, refreshed on change (poll, the file system's
  changes, optionally its watch), a missing file said, files and todos opened
  through the kit. The tab catalogue `forgeQuestLogFile`,
  `forgeQuestSessions` and `forgeQuestFoldersUnder`; the Todos tab's
  `ForgeQuestTodoSource` and `ForgeFolderFileSystem`. `ForgeQuestViewModule`
  contributes it with the placement hint `forgeQuestViewPlacement`
  (`forge.view.quest`). New dependencies: `path`, `tom_file_editors`,
  `tom_todo_ui`.

## 0.1.0

- The quest application frame before the quest runtime: `ForgeQuestsModule`
  (the `quest` application factory, at most one application per quest, and
  the Open Quest picker over `_ai/quests/`), the frame with placeholder views
  for @TOM, @TOM WS, @CHAT and @WS, and `ForgeQuestApplicationLifecycle`.

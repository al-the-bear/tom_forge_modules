/// The quest applications of Tom Forge, before the quest runtime: the
/// `quest` application factory, the quest picker over `_ai/quests/`, the
/// frame (@TOM and @TOM WS on the left, editors in the middle, @CHAT and @WS
/// at the bottom) with placeholder views, and the applications' lifecycle;
/// and the quest view, a kit view over a quest folder's AI files (the VS Code
/// extension's Logs panel tabs) that any application on the kit can place.
library;

export 'src/forge_quests_module.dart';
export 'src/quest_application.dart';
export 'src/quest_catalogue.dart';
export 'src/quest_view/forge_quest_files.dart';
export 'src/quest_view/forge_quest_todo_source.dart';
export 'src/quest_view/forge_quest_view.dart';
export 'src/quest_view/forge_quest_view_module.dart';
export 'src/quests_trail.dart' show kForgeQuestsDebug;

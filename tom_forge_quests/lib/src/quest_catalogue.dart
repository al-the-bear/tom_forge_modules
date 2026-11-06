import 'package:tom_file_system/tom_file_system.dart';

/// Where a workspace keeps its quests, relative to the workspace root.
const forgeQuestsFolder = '_ai/quests';

/// The quests of the workspace at [workspaceRoot]: the directories under its
/// `_ai/quests/` ([forgeQuestsFolder]), by name, sorted. A quest is its
/// folder — the same rule the VS Code extension's quest list follows — so a
/// folder without an overview is still a quest; files beside them
/// (`quests_overview.md`) and hidden entries are not. A workspace without the
/// folder has none.
Future<List<String>> listForgeQuests(
  TomFileSystem fileSystem,
  String workspaceRoot,
) async {
  final root = workspaceRoot.endsWith('/')
      ? workspaceRoot.substring(0, workspaceRoot.length - 1)
      : workspaceRoot;
  final folder = Uri.file('$root/$forgeQuestsFolder');
  if (!await fileSystem.exists(folder)) return const [];
  final entries = await fileSystem.list(folder);
  return [
    for (final entry in entries)
      if (entry.isDirectory && !entry.name.startsWith('.')) entry.name,
  ]..sort();
}

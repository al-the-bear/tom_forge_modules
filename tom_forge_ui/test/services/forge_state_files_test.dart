/// Forge's own state under `.forge/` is per machine and has no migrations: a
/// state file Forge cannot read — damaged, or written by another version —
/// counts as absent, and the workspace opens with fresh state
/// (`tom_forge/_copilot_guidelines/configuration_compatibility.md` §2).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  late TomMemoryFileSystem workspace;
  late DefaultWorkspaceStateManager state;

  setUp(() async {
    workspace = TomMemoryFileSystem(root: Uri.directory('/ws'));
    state = DefaultWorkspaceStateManager();
    await state.initialize(workspace);
  });

  /// Every `.json` under `.forge/`, overwritten with [content].
  Future<void> overwriteEvery(String content) async {
    final pending = [state.forgeDirectory];
    while (pending.isNotEmpty) {
      for (final entry in await workspace.list(pending.removeLast())) {
        if (entry.isDirectory) {
          pending.add(entry.uri);
        } else if (entry.name.endsWith('.json')) {
          await workspace.writeText(entry.uri, content);
        }
      }
    }
  }

  Future<List<Object?>> loadAll() async => [
    await state.loadOpenApplications(),
    await state.loadEditorState(workspace.uriOf('a.md')),
    await state.loadApplicationState('tom-forge'),
    await state.loadConfig(),
  ];

  Future<void> saveAll() async {
    await state.saveOpenApplications({'open': <Object?>[]});
    await state.saveEditorState(workspace.uriOf('a.md'), {
      'line': 3,
    });
    await state.saveApplicationState('tom-forge', {'groups': <Object?>[]});
    await state.saveConfig({'theme': 'dark'});
  }

  test('FS-1: what was saved loads back', () async {
    await saveAll();
    expect(await loadAll(), everyElement(isNotNull));
  });

  test('FS-2: a damaged state file counts as absent', () async {
    await saveAll();
    await overwriteEvery('{not json');
    expect(await loadAll(), everyElement(isNull));
  });

  test('FS-3: a state file of another shape counts as absent', () async {
    await saveAll();
    await overwriteEvery('[1, 2, 3]');
    expect(await loadAll(), everyElement(isNull));
  });
}

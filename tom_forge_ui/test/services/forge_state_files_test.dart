/// Forge's own state under `.forge/` is per machine and has no migrations: a
/// state file Forge cannot read — damaged, or written by another version —
/// counts as absent, and the workspace opens with fresh state
/// (`tom_forge/_copilot_guidelines/configuration_compatibility.md` §2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  late Directory workspace;
  late DefaultWorkspaceStateManager state;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('forge_state_files');
    state = DefaultWorkspaceStateManager();
    await state.initialize(workspace.path);
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  void overwriteEvery(String content) {
    for (final file in Directory(state.forgeDirectoryPath)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      file.writeAsStringSync(content);
    }
  }

  Future<List<Object?>> loadAll() async => [
    await state.loadOpenApplications(),
    await state.loadEditorState(Uri.file('${workspace.path}/a.md')),
    await state.loadApplicationState('tom-forge'),
    await state.loadConfig(),
  ];

  Future<void> saveAll() async {
    await state.saveOpenApplications({'open': <Object?>[]});
    await state.saveEditorState(Uri.file('${workspace.path}/a.md'), {
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
    overwriteEvery('{not json');
    expect(await loadAll(), everyElement(isNull));
  });

  test('FS-3: a state file of another shape counts as absent', () async {
    await saveAll();
    overwriteEvery('[1, 2, 3]');
    expect(await loadAll(), everyElement(isNull));
  });
}

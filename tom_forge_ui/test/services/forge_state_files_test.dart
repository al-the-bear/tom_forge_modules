/// Forge's own state under `.forge/` is per machine and has no migrations: a
/// state file Forge cannot read — damaged, or written by another version —
/// counts as absent, and the workspace opens with fresh state
/// (`tom_forge/_agent_guidelines/configuration_compatibility.md` §2).
library;

import 'dart:async';
import 'dart:typed_data';

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

  test('FS-4: two writes of one state file in flight land in the order they '
      'were started; a load and flushed wait for them', () async {
    // The first write of a file is held until released, so it would finish
    // after the second one without the order (forgeinv7: an older layout
    // written last).
    final slow = _HoldFirstWrite(root: Uri.directory('/slow'));
    final manager = DefaultWorkspaceStateManager();
    await manager.initialize(slow);

    final first = manager.saveApplicationState('alpha', {'layout': 'old'});
    final second = manager.saveApplicationState('alpha', {'layout': 'new'});
    final loaded = manager.loadApplicationState('alpha');
    var flushed = false;
    unawaited(manager.flushed().then((_) => flushed = true));
    await pumpEventQueue();
    expect(flushed, isFalse, reason: 'the first write is still held');

    slow.release();
    await Future.wait([first, second]);
    expect((await loaded)?['layout'], 'new');
    await pumpEventQueue();
    expect(flushed, isTrue);
    expect((await manager.loadApplicationState('alpha'))?['layout'], 'new');

    // flushed still answers after dispose (the shell disposes the manager in
    // the frame it writes its state at exit).
    manager.dispose();
    await manager.flushed();
  });
}

/// A memory file system whose first write of each file waits for [release].
class _HoldFirstWrite extends TomMemoryFileSystem {
  _HoldFirstWrite({required super.root});

  final _held = Completer<void>();
  final _written = <Uri>{};

  void release() => _held.complete();

  @override
  Future<TomFileRevision> write(
    Uri uri,
    Uint8List bytes, {
    TomFileRevision? expected,
  }) async {
    if (uri.path.endsWith('.json') && _written.add(uri)) await _held.future;
    return super.write(uri, bytes, expected: expected);
  }
}

/// The workspace's `.forge/` is kept out of git without editing a file the
/// workspace tracks (`tom_forge/_agent_guidelines/configuration_compatibility.md`
/// §2): git decides what is ignored, and what Forge adds goes to the clone's
/// own `.git/info/exclude`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

Future<void> _git(Directory dir, List<String> args) async {
  final result = await Process.run('git', ['-C', dir.path, ...args]);
  expect(result.exitCode, 0, reason: 'git ${args.join(' ')}: ${result.stderr}');
}

Future<bool> _ignored(Directory dir) async =>
    (await Process.run('git', [
      '-C',
      dir.path,
      'check-ignore',
      '-q',
      '.forge/',
    ])).exitCode ==
    0;

void main() {
  late Directory scratch;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('forge_state_git');
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  Future<Directory> repo({String? gitignore}) async {
    final dir = Directory('${scratch.path}/repo')..createSync();
    await _git(dir, ['init', '-q']);
    if (gitignore != null) {
      File('${dir.path}/.gitignore').writeAsStringSync(gitignore);
    }
    return dir;
  }

  test('GI-1: a folder outside git is left alone', () async {
    final dir = Directory('${scratch.path}/plain')..createSync();
    expect(
      await keepForgeStateOutOfGit(dir.path),
      ForgeStateIgnore.notInGit,
    );
    expect(dir.listSync(), isEmpty);
  });

  test('GI-2: a .gitignore that ignores .forge/ by another pattern is '
      'honoured; nothing is written', () async {
    for (final pattern in ['/.forge/', '**/.forge', '.forge']) {
      final dir = await repo(gitignore: 'build/\n$pattern\n');
      expect(
        await keepForgeStateOutOfGit(dir.path),
        ForgeStateIgnore.alreadyIgnored,
        reason: pattern,
      );
      expect(
        File('${dir.path}/.gitignore').readAsStringSync(),
        'build/\n$pattern\n',
      );
      dir.deleteSync(recursive: true);
    }
  });

  test('GI-3: when nothing ignores it, .forge/ goes to the clone\'s '
      'info/exclude and the tracked .gitignore is not touched; a second '
      'call writes nothing', () async {
    final dir = await repo(gitignore: 'build/\n');
    expect(
      await keepForgeStateOutOfGit(dir.path),
      ForgeStateIgnore.addedToLocalExclude,
    );
    expect(File('${dir.path}/.gitignore').readAsStringSync(), 'build/\n');
    expect(await _ignored(dir), isTrue);

    final exclude = File('${dir.path}/.git/info/exclude');
    final before = exclude.readAsStringSync();
    expect(before, contains('/.forge/'));
    expect(
      await keepForgeStateOutOfGit(dir.path),
      ForgeStateIgnore.alreadyIgnored,
    );
    expect(exclude.readAsStringSync(), before);
  });

  test('GI-4: a workspace in a subfolder of the repository: a parent '
      '.gitignore counts, and an added pattern is anchored at the '
      'workspace', () async {
    final dir = await repo(gitignore: '**/.forge/\n');
    final sub = Directory('${dir.path}/apps/one')..createSync(recursive: true);
    expect(
      await keepForgeStateOutOfGit(sub.path),
      ForgeStateIgnore.alreadyIgnored,
    );

    File('${dir.path}/.gitignore').writeAsStringSync('');
    expect(
      await keepForgeStateOutOfGit(sub.path),
      ForgeStateIgnore.addedToLocalExclude,
    );
    expect(
      File('${dir.path}/.git/info/exclude').readAsStringSync(),
      contains('/apps/one/.forge/'),
    );
    expect(await _ignored(sub), isTrue);
    expect(await _ignored(dir), isFalse, reason: 'only the workspace\'s');
  });
}

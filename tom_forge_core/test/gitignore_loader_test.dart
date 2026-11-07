/// The `.gitignore` walk Forge's quick open uses: which files it reads and
/// which folders it never enters. The rules themselves are `tom_basics`'
/// `TomGitignore`, tested there; these tests hold the walk.
library;

import 'package:test/test.dart';
import 'package:tom_basics/utilities.dart' show TomGitignoreSet;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

void main() {
  late Map<String, String> files;

  setUp(() => files = {});

  void write(String relative, String text) => files['/ws/$relative'] = text;

  Future<TomGitignoreSet> load() =>
      forgeLoadGitignores(TomMemoryFileSystem(root: Uri.directory('/ws'), seed: files));

  test('GITIGNORE-WALK-1: the root and nested files are read, the nested one '
      'deciding inside its folder', () async {
    write('.gitignore', '*.log\nbuild/\n');
    write('sub/.gitignore', '!keep.log\nout/\n');
    final rules = await load();
    expect(rules.files.map((f) => f.base), ['', 'sub']);
    expect(rules.isIgnored('a.log', isDirectory: false), isTrue);
    expect(rules.isIgnored('build', isDirectory: true), isTrue);
    expect(rules.isIgnored('build/x.dart', isDirectory: false), isTrue);
    expect(rules.isIgnored('sub/keep.log', isDirectory: false), isFalse);
    expect(rules.isIgnored('sub/other.log', isDirectory: false), isTrue);
    expect(rules.isIgnored('sub/out/x.txt', isDirectory: false), isTrue);
    expect(rules.isIgnored('out/x.txt', isDirectory: false), isFalse);
  });

  test('GITIGNORE-WALK-2: an ignored folder is not entered, so a .gitignore '
      'inside it has no effect', () async {
    write('.gitignore', 'vendor/\n');
    write('vendor/.gitignore', '!*\n');
    final rules = await load();
    expect(rules.files.map((f) => f.base), ['']);
    expect(rules.isIgnored('vendor/lib.dart', isDirectory: false), isTrue);
  });

  test('GITIGNORE-WALK-3: .git is never entered', () async {
    write('.git/.gitignore', '*\n');
    write('.git/info/.gitignore', '*\n');
    final rules = await load();
    expect(rules.files, isEmpty);
    expect(rules.isIgnored('lib/a.dart', isDirectory: false), isFalse);
  });

  test('GITIGNORE-WALK-4: a tree with no .gitignore ignores nothing',
      () async {
    write('lib/a.dart', '');
    final rules = await load();
    expect(rules.files, isEmpty);
    expect(rules.isIgnored('lib/a.dart', isDirectory: false), isFalse);
  });

  test('GITIGNORE-WALK-5: from a folder below the file system root, rules are '
      'relative to that folder', () async {
    final fs = TomMemoryFileSystem(seed: {
      '/elsewhere/.gitignore': '*\n',
      '/ws/.gitignore': '*.log\n',
      '/ws/sub/.gitignore': 'out/\n',
    });
    final rules = await forgeLoadGitignores(fs, root: Uri.directory('/ws'));
    expect(rules.files.map((f) => f.base), ['', 'sub']);
    expect(rules.isIgnored('a.log', isDirectory: false), isTrue);
    expect(rules.isIgnored('sub/out/x', isDirectory: false), isTrue);
    expect(rules.isIgnored('a.txt', isDirectory: false), isFalse);
  });
}

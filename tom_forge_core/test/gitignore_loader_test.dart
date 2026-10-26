/// The `.gitignore` walk Forge's quick open uses: which files it reads and
/// which folders it never enters. The rules themselves are `tom_basics`'
/// `TomGitignore`, tested there; these tests hold the walk.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('forge_gitignore_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String relative, String text) {
    final file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  test('GITIGNORE-WALK-1: the root and nested files are read, the nested one '
      'deciding inside its folder', () async {
    write('.gitignore', '*.log\nbuild/\n');
    write('sub/.gitignore', '!keep.log\nout/\n');
    final rules = await forgeLoadGitignores(root.path);
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
    final rules = await forgeLoadGitignores(root.path);
    expect(rules.files.map((f) => f.base), ['']);
    expect(rules.isIgnored('vendor/lib.dart', isDirectory: false), isTrue);
  });

  test('GITIGNORE-WALK-3: .git is never entered', () async {
    write('.git/.gitignore', '*\n');
    write('.git/info/.gitignore', '*\n');
    final rules = await forgeLoadGitignores(root.path);
    expect(rules.files, isEmpty);
    expect(rules.isIgnored('lib/a.dart', isDirectory: false), isFalse);
  });

  test('GITIGNORE-WALK-4: a trailing separator on the root is accepted, and '
      'a tree with no .gitignore ignores nothing', () async {
    write('lib/a.dart', '');
    final rules = await forgeLoadGitignores('${root.path}/');
    expect(rules.files, isEmpty);
    expect(rules.isIgnored('lib/a.dart', isDirectory: false), isFalse);
  });
}

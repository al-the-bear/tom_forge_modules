// Repo-sourced doc model (§9 item 5): the case-/extension-tolerant file picker
// that mirrors the website's repo_docs_loader, and the kind metadata the badge
// rows use. Pure-Dart — no Flutter or file system.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

Uri _f(String path) => Uri.file(path);

void main() {
  group('TWE-REPODOC-01: RepoDocKind metadata', () {
    test('stem + label per kind', () {
      expect(RepoDocKind.readme.stem, 'readme');
      expect(RepoDocKind.license.stem, 'license');
      expect(RepoDocKind.release.stem, 'release');
      expect(RepoDocKind.readme.label, 'README');
      expect(RepoDocKind.license.label, 'LICENSE');
      expect(RepoDocKind.release.label, 'release.md');
    });

    test('values are in display order README, LICENSE, release', () {
      expect(RepoDocKind.values,
          [RepoDocKind.readme, RepoDocKind.license, RepoDocKind.release]);
    });
  });

  group('TWE-REPODOC-02: pickRepoDocFile', () {
    test('matches a stem case-insensitively, any text extension', () {
      final files = [_f('/r/README.md'), _f('/r/other.txt')];
      expect(pickRepoDocFile(files, 'readme'), _f('/r/README.md'));
    });

    test('matches an extension-less LICENSE', () {
      final files = [_f('/r/LICENSE'), _f('/r/README.md')];
      expect(pickRepoDocFile(files, 'license'), _f('/r/LICENSE'));
    });

    test('prefers .md over a bare file when both exist', () {
      final files = [_f('/r/README'), _f('/r/README.md')];
      expect(pickRepoDocFile(files, 'readme'), _f('/r/README.md'));
    });

    test('skips a non-text extension (e.g. README.png)', () {
      expect(pickRepoDocFile([_f('/r/README.png')], 'readme'), isNull);
    });

    test('returns null when no file matches the stem', () {
      expect(pickRepoDocFile([_f('/r/CHANGELOG.md')], 'release'), isNull);
    });
  });

  group('TWE-REPODOC-03: RepoDocRef', () {
    test('fileName is the discovered file name', () {
      final ref =
          RepoDocRef(kind: RepoDocKind.readme, uri: _f('/r/README.md'));
      expect(ref.fileName, 'README.md');
    });
  });
}

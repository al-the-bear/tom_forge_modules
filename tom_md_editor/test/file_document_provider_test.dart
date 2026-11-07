/// The file-backed document provider loads and saves through the host's
/// file system (`TomFileSystem`): on disk, in memory or on the web alike.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

void main() {
  late TomMemoryFileSystem fs;

  setUp(() {
    fs = TomMemoryFileSystem(
      root: Uri.directory('/ws'),
      seed: {'/ws/docs/notes.md': '# Notes\n'},
    );
  });

  test('FDP-1: loads the file, and names the document after it', () async {
    final provider = FileDocumentProvider(
      fileSystem: fs,
      uri: fs.uriOf('docs/notes.md'),
    );
    expect(await provider.load(), '# Notes\n');
    expect(provider.metadata.title, 'notes.md');
    expect(provider.metadata.path, fs.uriOf('docs/notes.md').toFilePath());
  });

  test('FDP-2: a file that does not exist loads as an empty document', () async {
    final provider = FileDocumentProvider(
      fileSystem: fs,
      uri: fs.uriOf('docs/new.md'),
    );
    expect(await provider.load(), '');
  });

  test('FDP-3: saving writes the file, its folder made when missing', () async {
    final provider = FileDocumentProvider(
      fileSystem: fs,
      uri: fs.uriOf('drafts/today/plan.md'),
    );
    await provider.save('# Plan\n');
    expect(await fs.readText(fs.uriOf('drafts/today/plan.md')), '# Plan\n');
  });
}

/// What the workspace search reads: text files of the workspace, through the
/// file system — not build output, VCS folders, binaries or huge files — and
/// a file it cannot read does not end the search.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

void main() {
  Future<List<String>> found(TomFileSystem fs) async =>
      (await DefaultSearchManager(fileSystem: fs).search('needle'))
          .map((r) => fs.pathOf(r.uri)!)
          .toList()
        ..sort();

  Future<TomMemoryFileSystem> workspace(Map<String, String> files) async =>
      TomMemoryFileSystem(root: Uri.directory('/ws'), seed: files);

  test('SRCH-1: build output, tool and VCS folders are not searched', () async {
    final fs = await workspace({
      '/ws/lib/a.dart': 'needle',
      '/ws/build/out.js': 'needle',
      '/ws/.dart_tool/x.json': 'needle',
      '/ws/.git/HEAD': 'needle',
      '/ws/node_modules/m/index.js': 'needle',
    });
    expect(await found(fs), ['lib/a.dart']);
  });

  test('SRCH-2: a file whose content is not text is not searched, whatever '
      'its name', () async {
    final fs = await workspace({'/ws/a.txt': 'needle'});
    await fs.write(
      fs.uriOf('blob.txt'),
      Uint8List.fromList([0, 1, 2, ...'needle'.codeUnits, 0, 0]),
    );
    // A PNG's signature and header: binary, with the text in a chunk.
    await fs.write(
      fs.uriOf('image.png'),
      Uint8List.fromList([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13,
        ...'IHDRneedle'.codeUnits, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
      ]),
    );
    expect(await found(fs), ['a.txt']);
  });

  test('SRCH-3: a file over the size limit is not read', () async {
    final fs = await workspace({
      '/ws/small.txt': 'needle',
      '/ws/huge.log': 'needle${'x' * (DefaultSearchManager.maxFileSizeBytes)}',
    });
    expect(await found(fs), ['small.txt']);
  });

  test('SRCH-4: a file that cannot be read is passed over; the search goes '
      'on', () async {
    final fs = await workspace({'/ws/a.txt': 'needle', '/ws/b.txt': 'needle'});
    await fs.write(
      fs.uriOf('bad.txt'),
      Uint8List.fromList([...'needle '.codeUnits, 0xff, 0xfe, 0xfd]),
    );
    expect(await found(fs), containsAll(['a.txt', 'b.txt']));
  });
}

/// File kinds: a kind takes a file by its extension, any case; the registry
/// asks its kinds in order, the first that matches taking the file, and a
/// kind registered again under its id replaces the old one in its place.
library;

import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

ForgeKitFileKind _kind(String id, List<String> extensions) => ForgeKitFileKind(
  id: id,
  label: id,
  icon: const IconData(0xe24d, fontFamily: 'MaterialIcons'),
  extensions: extensions,
  create: (_) => throw UnimplementedError(),
);

void main() {
  test('FK-1: a kind takes a file by its extension, any case', () {
    final markdown = _kind('markdown', ['md', 'markdown']);
    expect(markdown.matches('notes.md'), isTrue);
    expect(markdown.matches('README.MARKDOWN'), isTrue);
    expect(markdown.matches('md'), isFalse, reason: 'no extension');
    expect(markdown.matches('notes.mdx'), isFalse);
  });

  test('FK-2: the registry asks its kinds in order; the first match takes '
      'the file', () {
    final yaml = _kind('yaml', ['yaml', 'yml']);
    final spec = _kind('spec', ['spec.yaml']);
    final registry = ForgeFileKindRegistry([yaml, spec]);
    expect(registry.kinds, [yaml, spec]);
    expect(registry.kindOf('a.spec.yaml'), same(yaml), reason: 'asked first');
    expect(registry.kindOf('b.yml'), same(yaml));
    expect(registry.kindOf('c.txt'), isNull);
    expect(registry.byId('spec'), same(spec));
    expect(registry.byId('none'), isNull);
  });

  test('FK-3: a kind registered under an id already there replaces it in its '
      'place', () {
    final registry = ForgeFileKindRegistry([
      _kind('markdown', ['md']),
      _kind('yaml', ['yaml']),
    ]);
    final other = _kind('markdown', ['md', 'markdown']);
    registry.register(other);
    expect(registry.kinds.map((k) => k.id), ['markdown', 'yaml']);
    expect(registry.kindOf('a.markdown'), same(other));
    expect(() => registry.kinds.add(other), throwsUnsupportedError);
  });
}

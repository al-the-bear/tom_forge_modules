// WebsiteStructureController (§6b): scans the active website's `content/` tree
// through the [WebsiteContentFs] seam and builds a filesystem-driven structure
// tree (site.yaml, areas/, components/, copy/ [grouped by §16], pages/,
// diagrams/). These tests cover the disabled state, the tree mirroring content/,
// §16 copy grouping, editor-kind routing, new-file creation at the convention
// path, and placeholder-error surfacing.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _config = '''
version: 1
websites:
  - id: alpha
    label: Alpha
    paths:
      websiteRoot: "/sites/a"
    content:
      dir: "{websiteRoot}/content"
  - id: beta
    paths:
      websiteRoot: "/sites/b"
  - id: broken
    paths:
      websiteRoot: "/sites/c"
    content:
      dir: "{unknownToken}/content"
''';

/// In-memory [WebsiteContentFs] that infers directories from file paths so the
/// explorer's directory listing can be exercised without a real disk.
class _FakeFs implements WebsiteContentFs {
  _FakeFs(this.files);

  final Map<Uri, String> files;
  final List<({Uri uri, String content})> writes = [];

  static String _prefix(Uri dir) =>
      dir.path.endsWith('/') ? dir.path : '${dir.path}/';

  @override
  Future<List<Uri>> listFiles(Uri directory) async {
    final prefix = _prefix(directory);
    return [
      for (final uri in files.keys)
        if (uri.path.startsWith(prefix) &&
            !uri.path.substring(prefix.length).contains('/'))
          uri,
    ];
  }

  @override
  Future<List<ContentFsEntry>> listEntries(Uri directory) async {
    final prefix = _prefix(directory);
    final entries = <String, ContentFsEntry>{};
    for (final uri in files.keys) {
      if (!uri.path.startsWith(prefix)) continue;
      final remainder = uri.path.substring(prefix.length);
      final slash = remainder.indexOf('/');
      if (slash < 0) {
        entries[remainder] = ContentFsEntry(uri: uri, isDirectory: false);
      } else {
        final dirName = remainder.substring(0, slash);
        entries.putIfAbsent(
          dirName,
          () => ContentFsEntry(
            uri: Uri.file('$prefix$dirName/'),
            isDirectory: true,
          ),
        );
      }
    }
    return entries.values.toList();
  }

  @override
  Future<String> read(Uri uri) async => files[uri] ?? '';

  @override
  Future<void> write(Uri uri, String content) async {
    files[uri] = content;
    writes.add((uri: uri, content: content));
  }

  @override
  Future<bool> exists(Uri uri) async {
    if (files.containsKey(uri)) return true;
    final prefix = _prefix(uri);
    return files.keys.any((u) => u.path.startsWith(prefix));
  }

  @override
  Future<void> delete(Uri uri) async {
    files.remove(uri);
    final prefix = _prefix(uri);
    files.removeWhere((u, _) => u.path.startsWith(prefix));
  }

  @override
  Future<void> rename(Uri from, Uri to) async {
    final content = files.remove(from);
    if (content != null) files[to] = content;
  }
}

Future<(WebsiteStructureController, _FakeFs)> _loaded({
  required String activeId,
  Map<Uri, String>? seed,
}) async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  editor.selectWebsite(activeId);
  final fs = _FakeFs(seed ?? _seed());
  final controller =
      WebsiteStructureController(editor: editor, fileSystem: fs);
  await controller.refresh();
  return (controller, fs);
}

Map<Uri, String> _seed() => {
      Uri.file('/sites/a/content/site.yaml'): 'home: {}',
      Uri.file('/sites/a/content/components/button.yaml'): 'id: button',
      Uri.file('/sites/a/content/components/card.yaml'): 'id: card',
      Uri.file('/sites/a/content/copy/home.md'): '# home',
      Uri.file('/sites/a/content/copy/auth_component.md'): '# auth',
      Uri.file('/sites/a/content/copy/auth_login_module.md'): '# login',
      Uri.file('/sites/a/content/copy/platform_area.md'): '# platform',
      Uri.file('/sites/a/content/pages/about.md'): '# about',
      Uri.file('/sites/a/content/areas/platform.md'): '# area',
      Uri.file('/sites/a/content/diagrams/auth/flow.svg'): '<svg/>',
    };

StructureNode _section(WebsiteStructureController c, String label) =>
    c.nodes.firstWhere((n) => n.label == label);

void main() {
  group('WebsiteStructureController', () {
    // WSC-01: disabled when the active website has no content block.
    test('WSC-01: disabled without a content block', () async {
      final (controller, _) = await _loaded(activeId: 'beta');
      expect(controller.isEnabled, isFalse);
      expect(controller.nodes, isEmpty);
    });

    // WSC-02: the tree mirrors content/ — a section per content area.
    test('WSC-02: tree mirrors the content/ sections', () async {
      final (controller, _) = await _loaded(activeId: 'alpha');
      expect(controller.isEnabled, isTrue);
      final labels = controller.nodes.map((n) => n.label).toList();
      expect(
        labels,
        containsAll(
            ['site.yaml', 'areas', 'components', 'copy', 'pages', 'diagrams']),
      );
    });

    // WSC-03: components list .yaml files; pages list .md files.
    test('WSC-03: sections list their files', () async {
      final (controller, _) = await _loaded(activeId: 'alpha');
      final components = _section(controller, 'components');
      expect(components.children.map((n) => n.label),
          containsAll(['button.yaml', 'card.yaml']));
      final pages = _section(controller, 'pages');
      expect(pages.children.single.label, 'about.md');
    });

    // WSC-04: editor-kind routing — .yaml → yaml, .md → markdown.
    test('WSC-04: files route to the right editor kind', () async {
      final (controller, _) = await _loaded(activeId: 'alpha');
      final yaml = _section(controller, 'components').children.first;
      expect(yaml.editorKind, FileEditorKind.yaml);
      final page = _section(controller, 'pages').children.single;
      expect(page.editorKind, FileEditorKind.markdown);
    });

    // WSC-05: copy/ is grouped by the §16 naming convention.
    test('WSC-05: copy files group by the §16 convention', () async {
      final (controller, _) = await _loaded(activeId: 'alpha');
      final copy = _section(controller, 'copy');
      final auth = copy.children.firstWhere((n) => n.label == 'auth');
      expect(auth.children.map((n) => n.label), contains('login'));
      expect(copy.children.map((n) => n.label), contains('home'));
    });

    // WSC-06: a new copy file lands at the §16 convention path under copy/.
    test('WSC-06: createCopyFile writes the convention path', () async {
      final (controller, fs) = await _loaded(activeId: 'alpha');
      final uri = await controller.createCopyFile(
        CopyFileKind.component,
        parts: ['billing'],
      );
      expect(uri.path, '/sites/a/content/copy/billing_component.md');
      expect(fs.files.containsKey(uri), isTrue);
      // After creation the tree shows the new component group.
      final copy = _section(controller, 'copy');
      expect(copy.children.map((n) => n.label), contains('billing'));
    });

    // WSC-07: a placeholder-resolution failure is surfaced via error, not a
    // silent blank tree.
    test('WSC-07: placeholder error surfaced', () async {
      final (controller, _) = await _loaded(activeId: 'broken');
      expect(controller.error, isNotNull);
      expect(controller.error, contains('unknownToken'));
      expect(controller.nodes, isEmpty);
    });

    // WSC-08: createFile writes a new file and the tree shows it after refresh.
    test('WSC-08: createFile writes and surfaces the new file', () async {
      final (controller, fs) = await _loaded(activeId: 'alpha');
      final uri = Uri.file('/sites/a/content/components/hero.yaml');
      final created =
          await controller.createFile(uri, content: 'id: hero\n');
      expect(created, uri);
      expect(fs.files[uri], 'id: hero\n');
      final components = _section(controller, 'components');
      expect(components.children.map((n) => n.label), contains('hero.yaml'));
    });

    // WSC-09: deleteFile removes the file from disk and from the tree.
    test('WSC-09: deleteFile removes the file', () async {
      final (controller, fs) = await _loaded(activeId: 'alpha');
      final uri = Uri.file('/sites/a/content/components/button.yaml');
      expect(fs.files.containsKey(uri), isTrue);
      await controller.deleteFile(uri);
      expect(fs.files.containsKey(uri), isFalse);
      final components = _section(controller, 'components');
      expect(components.children.map((n) => n.label),
          isNot(contains('button.yaml')));
      expect(components.children.map((n) => n.label), contains('card.yaml'));
    });

    // WSC-10: renameFile moves the file to a sibling path and updates the tree.
    test('WSC-10: renameFile renames within the directory', () async {
      final (controller, fs) = await _loaded(activeId: 'alpha');
      final from = Uri.file('/sites/a/content/components/button.yaml');
      final to = await controller.renameFile(from, 'pressable.yaml');
      expect(to, Uri.file('/sites/a/content/components/pressable.yaml'));
      expect(fs.files.containsKey(from), isFalse);
      expect(fs.files.containsKey(to), isTrue);
      final components = _section(controller, 'components');
      final labels = components.children.map((n) => n.label).toList();
      expect(labels, contains('pressable.yaml'));
      expect(labels, isNot(contains('button.yaml')));
    });

    // WSC-11: renameFile rejects an empty name or a name with a path separator.
    test('WSC-11: renameFile validates the new name', () async {
      final (controller, _) = await _loaded(activeId: 'alpha');
      final from = Uri.file('/sites/a/content/components/button.yaml');
      expect(() => controller.renameFile(from, ''), throwsArgumentError);
      expect(() => controller.renameFile(from, '   '), throwsArgumentError);
      expect(
          () => controller.renameFile(from, 'sub/x.yaml'), throwsArgumentError);
    });
  });

  group('filterStructureNodes', () {
    StructureNode dir(String label, List<StructureNode> children) =>
        StructureNode(
          label: label,
          kind: StructureNodeKind.directory,
          children: children,
        );
    StructureNode file(String label) =>
        fileNode(Uri.file('/x/$label'), label: label);

    final tree = [
      dir('components', [file('button.yaml'), file('card.yaml')]),
      dir('pages', [file('about.md')]),
    ];

    // WSC-FILTER-01: an empty query returns the original list unchanged.
    test('WSC-FILTER-01: empty query is a no-op', () {
      expect(identical(filterStructureNodes(tree, ''), tree), isTrue);
      expect(identical(filterStructureNodes(tree, '   '), tree), isTrue);
    });

    // WSC-FILTER-02: a leaf match keeps the leaf and its ancestor directory,
    // pruning non-matching siblings and subtrees.
    test('WSC-FILTER-02: leaf match keeps matching leaf + ancestor', () {
      final filtered = filterStructureNodes(tree, 'button');
      expect(filtered, hasLength(1));
      expect(filtered.single.label, 'components');
      expect(filtered.single.children.map((n) => n.label), ['button.yaml']);
    });

    // WSC-FILTER-03: a directory-label match keeps the whole subtree.
    test('WSC-FILTER-03: directory match keeps the whole subtree', () {
      final filtered = filterStructureNodes(tree, 'pages');
      expect(filtered, hasLength(1));
      expect(filtered.single.label, 'pages');
      expect(filtered.single.children.map((n) => n.label), ['about.md']);
    });

    // WSC-FILTER-04: a no-match query prunes everything.
    test('WSC-FILTER-04: no match yields an empty list', () {
      expect(filterStructureNodes(tree, 'zzz'), isEmpty);
    });
  });
}

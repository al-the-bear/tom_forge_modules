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
  });
}

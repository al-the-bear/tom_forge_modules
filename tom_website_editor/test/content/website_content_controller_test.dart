// WebsiteContentController (§6a): builds the component catalog, site file, and
// pages from the active website's `content:` block through an injectable
// [WebsiteContentFs] seam, writes `# @manual` pins back to disk, and disables
// itself for websites without a `content:` block.
//
// The seam is faked in-memory (keyed by file Uri) so these tests exercise the
// catalog/refresh/pin logic without a real file system or forge shell.
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
''';

const _badConfig = '''
version: 1
websites:
  - id: alpha
    paths:
      websiteRoot: "/sites/a"
    content:
      dir: "{nope}/content"
''';

const _button = '''
id: button
name: Button
tagline: A clickable thing
status: stable
modules:
  - id: primary
    name: Primary
    color: blue
    submodules:
      - id: large
        size: lg
  - id: secondary
    color: gray
''';

const _card = '''
id: card
name: Card
tagline: A surface
''';

/// In-memory [WebsiteContentFs] keyed by file Uri.
class _FakeContentFs implements WebsiteContentFs {
  _FakeContentFs(this.files);

  final Map<Uri, String> files;
  final List<({Uri uri, String content})> writes = [];

  @override
  Future<List<Uri>> listFiles(Uri directory) async {
    final prefix = _dirPrefix(directory);
    return [
      for (final uri in files.keys)
        if (uri.path.startsWith(prefix) &&
            !uri.path.substring(prefix.length).contains('/'))
          uri,
    ];
  }

  @override
  Future<String> read(Uri uri) async => files[uri]!;

  @override
  Future<void> write(Uri uri, String content) async {
    files[uri] = content;
    writes.add((uri: uri, content: content));
  }

  @override
  Future<bool> exists(Uri uri) async {
    if (files.containsKey(uri)) return true;
    final prefix = _dirPrefix(uri);
    return files.keys.any((u) => u.path.startsWith(prefix));
  }

  static String _dirPrefix(Uri uri) =>
      uri.path.endsWith('/') ? uri.path : '${uri.path}/';
}

Uri _file(String path) => Uri.file(path);

Map<Uri, String> _seed() => {
      _file('/sites/a/content/components/button.yaml'): _button,
      _file('/sites/a/content/components/card.yaml'): _card,
      _file('/sites/a/content/site.yaml'): 'title: My Site',
      _file('/sites/a/content/pages/intro.md'): '# Intro',
    };

Future<(WebsiteContentController, _FakeContentFs)> _loaded(
  String config, {
  Map<Uri, String>? seed,
}) async {
  final editor = WebsiteEditorController(configReader: () async => config);
  await editor.load();
  final fs = _FakeContentFs(seed ?? _seed());
  final controller =
      WebsiteContentController(editor: editor, fileSystem: fs);
  await controller.refresh();
  return (controller, fs);
}

void main() {
  group('TWE-CTRL-01: catalog build', () {
    test('builds component → module → submodule from components/*.yaml',
        () async {
      final (controller, _) = await _loaded(_config);

      expect(controller.isEnabled, isTrue);
      expect(controller.components, hasLength(2));
      // Sorted by path: button before card.
      final button = controller.components.first.record;
      expect(button.id, 'button');
      expect(button.children, hasLength(2));
      expect(button.children.first.children, hasLength(1),
          reason: 'primary has one submodule');
      expect(button.children[1].children, isEmpty,
          reason: 'secondary has no submodules');
    });

    test('discovers the site file and pages', () async {
      final (controller, _) = await _loaded(_config);
      expect(controller.siteFile, isNotNull);
      expect(controller.siteFile!.pathSegments.last, 'site.yaml');
      expect(controller.pages, hasLength(1));
      expect(controller.pages.single.pathSegments.last, 'intro.md');
    });
  });

  group('TWE-CTRL-02: pin a managed field', () {
    test('writes the pin to disk and re-parses the document', () async {
      final (controller, fs) = await _loaded(_config);
      final document = controller.components.first;
      final status =
          document.record.fields.firstWhere((f) => f.name == 'status');
      expect(status.isEditable, isFalse);

      final pinned = await controller.pinField(document, status);
      expect(pinned, isTrue);

      // The file on disk now carries the pin (survives generateContent).
      expect(fs.files[document.uri], contains('status: stable  # @manual'));

      // The controller re-parsed: the field is now editable + pinned.
      final reStatus = controller.components.first.record.fields
          .firstWhere((f) => f.name == 'status');
      expect(reStatus.isPinned, isTrue);
      expect(reStatus.isEditable, isTrue);
    });

    test('returns false when the field is already pinned', () async {
      final (controller, _) = await _loaded(_config);
      final document = controller.components.first;
      final status =
          document.record.fields.firstWhere((f) => f.name == 'status');
      await controller.pinField(document, status);
      // Re-pin the now-pinned field from the refreshed document.
      final refreshed = controller.components.first;
      final reStatus = refreshed.record.fields
          .firstWhere((f) => f.name == 'status');
      expect(await controller.pinField(refreshed, reStatus), isFalse);
    });
  });

  group('TWE-CTRL-03: disabled without a content block', () {
    test('isEnabled is false and the catalog is empty', () async {
      final editor =
          WebsiteEditorController(configReader: () async => _config);
      await editor.load();
      editor.selectWebsite('beta');
      final controller = WebsiteContentController(
          editor: editor, fileSystem: _FakeContentFs(_seed()));
      await controller.refresh();

      expect(controller.isEnabled, isFalse);
      expect(controller.components, isEmpty);
      expect(controller.pages, isEmpty);
      expect(controller.siteFile, isNull);
    });
  });

  group('TWE-CTRL-04: refresh reloads from disk', () {
    test('picks up a newly added component', () async {
      final (controller, fs) = await _loaded(_config);
      expect(controller.components, hasLength(2));

      fs.files[_file('/sites/a/content/components/zebra.yaml')] =
          'id: zebra\nname: Zebra\n';
      await controller.refresh();
      expect(controller.components, hasLength(3));
      expect(controller.components.last.record.id, 'zebra');
    });
  });

  group('TWE-CTRL-05: placeholder failure', () {
    test('surfaces an error and leaves the catalog empty', () async {
      final (controller, _) = await _loaded(_badConfig);
      expect(controller.error, isNotNull);
      expect(controller.error, contains('nope'));
      expect(controller.components, isEmpty);
    });
  });
}

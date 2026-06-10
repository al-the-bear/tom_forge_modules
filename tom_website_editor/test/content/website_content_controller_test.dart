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
  Future<List<ContentFsEntry>> listEntries(Uri directory) async => [
        for (final uri in await listFiles(directory))
          ContentFsEntry(uri: uri, isDirectory: false),
      ];

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

  @override
  Future<void> delete(Uri uri) async {
    files.remove(uri);
    final prefix = _dirPrefix(uri);
    files.removeWhere((u, _) => u.path.startsWith(prefix));
  }

  @override
  Future<void> rename(Uri from, Uri to) async {
    final content = files.remove(from);
    if (content != null) files[to] = content;
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

  group('TWE-CTRL-08: unpin a pinned field', () {
    test('removes the pin from disk and re-parses as managed', () async {
      final (controller, fs) = await _loaded(_config);
      final document = controller.components.first;
      final status =
          document.record.fields.firstWhere((f) => f.name == 'status');

      // Pin it first, then unpin from the refreshed document.
      await controller.pinField(document, status);
      final pinnedDoc = controller.components.first;
      final pinnedStatus =
          pinnedDoc.record.fields.firstWhere((f) => f.name == 'status');
      expect(pinnedStatus.isPinned, isTrue);

      final unpinned = await controller.unpinField(pinnedDoc, pinnedStatus);
      expect(unpinned, isTrue);

      // The marker is gone from disk.
      expect(fs.files[document.uri], isNot(contains('# @manual')));
      expect(fs.files[document.uri], contains('status: stable'));

      // The controller re-parsed: the field reverts to managed.
      final reStatus = controller.components.first.record.fields
          .firstWhere((f) => f.name == 'status');
      expect(reStatus.isPinned, isFalse);
      expect(reStatus.isEditable, isFalse);
    });

    test('returns false when the field is not pinned', () async {
      final (controller, _) = await _loaded(_config);
      final document = controller.components.first;
      final status =
          document.record.fields.firstWhere((f) => f.name == 'status');
      expect(status.isPinned, isFalse);
      expect(await controller.unpinField(document, status), isFalse);
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

  group('TWE-CTRL-06: edit an editable field', () {
    test('writes the new value to disk and re-parses', () async {
      final (controller, fs) = await _loaded(_config);
      final document = controller.components.first;
      final tagline =
          document.record.fields.firstWhere((f) => f.name == 'tagline');
      expect(tagline.isEditable, isTrue);

      final wrote =
          await controller.setFieldValue(document, tagline, 'Pressable');
      expect(wrote, isTrue);
      expect(fs.files[document.uri], contains('tagline: Pressable'));
      expect(fs.files[document.uri], contains('id: button'),
          reason: 'the rest of the document is intact');

      // The controller re-parsed: the new value is reflected.
      final reTagline = controller.components.first.record.fields
          .firstWhere((f) => f.name == 'tagline');
      expect(reTagline.value, 'Pressable');
    });

    test('a managed field is a no-op', () async {
      final (controller, fs) = await _loaded(_config);
      final document = controller.components.first;
      final status =
          document.record.fields.firstWhere((f) => f.name == 'status');
      expect(status.isEditable, isFalse);

      final wrote =
          await controller.setFieldValue(document, status, 'beta');
      expect(wrote, isFalse);
      expect(fs.writes, isEmpty);
    });

    test('an unchanged value is a no-op', () async {
      final (controller, fs) = await _loaded(_config);
      final document = controller.components.first;
      final tagline =
          document.record.fields.firstWhere((f) => f.name == 'tagline');

      final wrote =
          await controller.setFieldValue(document, tagline, tagline.value);
      expect(wrote, isFalse);
      expect(fs.writes, isEmpty);
    });

    test('a pinned field keeps its # @manual marker', () async {
      final (controller, fs) = await _loaded(_config);
      // Pin the managed "status" field, then edit it through the refreshed doc.
      final document = controller.components.first;
      final status =
          document.record.fields.firstWhere((f) => f.name == 'status');
      await controller.pinField(document, status);

      final pinnedDoc = controller.components.first;
      final pinnedStatus = pinnedDoc.record.fields
          .firstWhere((f) => f.name == 'status');
      expect(pinnedStatus.isPinned, isTrue);

      final wrote =
          await controller.setFieldValue(pinnedDoc, pinnedStatus, 'beta');
      expect(wrote, isTrue);
      expect(fs.files[pinnedDoc.uri], contains('status: beta  # @manual'));
    });
  });

  group('TWE-CTRL-07: copy files (§16 front-matter + body)', () {
    // A live-shaped §16 copy file: unsuffixed `tagline` / `summary` / `enables`
    // front-matter (the canonical editableFields) + the overview as the body.
    const copySource = '''
---
tagline: A clickable thing
summary: A button.
enables: [forms, dialogs]
---
<!-- @tom:override -->
# Overview

Hand text.

<!-- @tom:managed -->
Generated rollup.
''';

    Map<Uri, String> seedWithCopy() => {
          ..._seed(),
          _file('/sites/a/content/copy/button_component.md'): copySource,
          _file('/sites/a/content/copy/home.md'): '---\ntitle: Home\n---\nHi.\n',
        };

    test('loads copy files from the content.copy glob, sorted by path',
        () async {
      final (controller, _) = await _loaded(_config, seed: seedWithCopy());
      expect(controller.copyFiles, hasLength(2));
      expect(controller.copyFiles.first.uri.pathSegments.last,
          'button_component.md');
      final loaded = controller.copyFiles.first.file;
      expect(loaded.frontMatterValue('tagline'), 'A clickable thing');
      // The canonical §16 editableFields all round-trip from disk.
      expect(loaded.frontMatterValue('summary'), 'A button.');
      expect(loaded.frontMatterValue('enables'), 'forms, dialogs');
    });

    test('editing the summary / enables front-matter writes + re-parses',
        () async {
      final (controller, fs) = await _loaded(_config, seed: seedWithCopy());
      final document = controller.copyFiles.first;

      final wroteSummary = await controller.setCopyFrontMatterValue(
          document, 'summary', 'A pressable button.');
      expect(wroteSummary, isTrue);
      expect(fs.files[document.uri], contains('summary: A pressable button.'));
      expect(controller.copyFiles.first.file.frontMatterValue('summary'),
          'A pressable button.');

      final wroteEnables = await controller.setCopyFrontMatterValue(
          controller.copyFiles.first, 'enables', 'forms');
      expect(wroteEnables, isTrue);
      expect(controller.copyFiles.first.file.frontMatterValue('enables'),
          'forms');
    });

    test('editing a front-matter field writes to disk and re-parses', () async {
      final (controller, fs) = await _loaded(_config, seed: seedWithCopy());
      final document = controller.copyFiles.first;

      final wrote = await controller.setCopyFrontMatterValue(
          document, 'tagline', 'A pressable thing');
      expect(wrote, isTrue);
      expect(fs.files[document.uri], contains('tagline: A pressable thing'));
      // Re-parsed in place.
      expect(controller.copyFiles.first.file.frontMatterValue('tagline'),
          'A pressable thing');
      // An unchanged value is a no-op.
      final again = await controller.setCopyFrontMatterValue(
          controller.copyFiles.first, 'tagline', 'A pressable thing');
      expect(again, isFalse);
    });

    test('editing the body override region survives generate (markers + '
        'managed region preserved)', () async {
      final (controller, fs) = await _loaded(_config, seed: seedWithCopy());
      final document = controller.copyFiles.first;
      final overrideIndex = document.file.body.regions
          .indexWhere((r) => r.kind == ContentRegionKind.editable);

      final newBody =
          document.file.body.withRegionBody(overrideIndex, '# Overview\n\nEdited.');
      final wrote = await controller.setCopyBody(document, newBody);
      expect(wrote, isTrue);

      final onDisk = fs.files[document.uri]!;
      expect(onDisk, contains('Edited.'));
      expect(onDisk, contains('<!-- @tom:managed -->'));
      expect(onDisk, contains('Generated rollup.'));
      expect(onDisk, contains('tagline: A clickable thing'),
          reason: 'front-matter preserved');

      // A post-generate refresh from disk keeps the edit.
      await controller.refresh();
      expect(controller.copyFiles.first.file.serialize(), contains('Edited.'));
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

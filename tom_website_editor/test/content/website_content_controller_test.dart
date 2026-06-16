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
      expect(controller.pages.single.uri.pathSegments.last, 'intro.md');
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

    // §9 item 2: site-level copy (home.md, news.md) is exposed separately from
    // the per-entity copy files so the §6a browser can surface it together.
    test('siteLevelCopyFiles returns only home.md and news.md', () async {
      final (controller, _) = await _loaded(_config, seed: {
        ..._seed(),
        _file('/sites/a/content/copy/button_component.md'): copySource,
        _file('/sites/a/content/copy/home.md'): '# Home\n',
        _file('/sites/a/content/copy/news.md'): '# News\n',
      });

      final names = controller.siteLevelCopyFiles
          .map((d) => d.uri.pathSegments.last)
          .toList();
      expect(names, ['home.md', 'news.md']);
      // The per-entity component copy is not site-level.
      expect(names, isNot(contains('button_component.md')));
      // All three are still in the flat copy listing.
      expect(controller.copyFiles, hasLength(3));
    });
  });

  group('TWE-CTRL-10: standalone pages (§9 item 3: front-matter + body)', () {
    // A live-shaped standalone page: `title` / `route` front-matter scalars
    // above a region-aware Markdown body (override + managed regions).
    const pageSource = '''
---
title: Impressum
route: /impressum
---
<!-- @tom:override -->
# Impressum

Hand-authored legal text.

<!-- @tom:managed -->
Generated footer.
''';

    Map<Uri, String> seedWithPage() => {
          ..._seed(),
          _file('/sites/a/content/pages/impressum.md'): pageSource,
        };

    test('parses page front-matter (title/route) and body', () async {
      final (controller, _) = await _loaded(_config, seed: seedWithPage());
      // Sorted by path: impressum.md before intro.md.
      final page = controller.pages.first;
      expect(page.uri.pathSegments.last, 'impressum.md');
      expect(page.file.frontMatterValue('title'), 'Impressum');
      expect(page.file.frontMatterValue('route'), '/impressum');
      // The override region body is present.
      expect(
        page.file.body.regions
            .any((r) => r.kind == ContentRegionKind.editable),
        isTrue,
      );
    });

    test('editing the route front-matter writes to disk and re-parses',
        () async {
      final (controller, fs) = await _loaded(_config, seed: seedWithPage());
      final page = controller.pages.first;

      final wrote = await controller.setPageFrontMatterValue(
          page, 'route', '/legal/impressum');
      expect(wrote, isTrue);
      expect(fs.files[page.uri], contains('route: /legal/impressum'));
      // The body and other front-matter are preserved.
      expect(fs.files[page.uri], contains('title: Impressum'));
      expect(fs.files[page.uri], contains('Hand-authored legal text.'));
      // Re-parsed in place.
      expect(controller.pages.first.file.frontMatterValue('route'),
          '/legal/impressum');

      // An unchanged value is a no-op.
      final again = await controller.setPageFrontMatterValue(
          controller.pages.first, 'route', '/legal/impressum');
      expect(again, isFalse);
    });

    test('editing the body override region preserves managed regions + markers',
        () async {
      final (controller, fs) = await _loaded(_config, seed: seedWithPage());
      final page = controller.pages.first;
      final overrideIndex = page.file.body.regions
          .indexWhere((r) => r.kind == ContentRegionKind.editable);

      final newBody = page.file.body
          .withRegionBody(overrideIndex, '# Impressum\n\nEdited legal text.');
      final wrote = await controller.setPageBody(page, newBody);
      expect(wrote, isTrue);

      final onDisk = fs.files[page.uri]!;
      expect(onDisk, contains('Edited legal text.'));
      expect(onDisk, contains('<!-- @tom:managed -->'));
      expect(onDisk, contains('Generated footer.'));
      expect(onDisk, contains('route: /impressum'),
          reason: 'front-matter preserved');

      // A post-generate refresh from disk keeps the edit.
      await controller.refresh();
      expect(controller.pages.first.file.serialize(),
          contains('Edited legal text.'));
    });

    test('a page without front-matter still loads (body-only)', () async {
      final (controller, _) = await _loaded(_config);
      // The default seed has pages/intro.md = '# Intro' (no front-matter).
      final page = controller.pages.single;
      expect(page.uri.pathSegments.last, 'intro.md');
      expect(page.file.frontMatter, isEmpty);
      expect(page.file.serialize(), '# Intro');
    });
  });

  group('TWE-CTRL-09: edit module groups (§9 item 1)', () {
    const grouped = '''
id: button
name: Button
groups:
  - label: Primary actions
    members: [primary, secondary]
modules:
  - id: primary
    name: Primary
  - id: secondary
    name: Secondary
  - id: icon
    name: Icon
''';

    Map<Uri, String> seedWithGroups() => {
          ..._seed(),
          _file('/sites/a/content/components/button.yaml'): grouped,
        };

    test('writes a renamed group + new members and re-parses', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithGroups());
      final document = controller.components.first;
      expect(document.record.groups.single.label, 'Primary actions');

      final wrote = await controller.setGroups(document, const [
        ContentGroup(label: 'Main actions', members: ['primary', 'icon']),
      ]);
      expect(wrote, isTrue);

      // The block on disk reflects the edit; generator-owned fields survive.
      expect(fs.files[document.uri], contains('label: Main actions'));
      expect(fs.files[document.uri], contains('members: [primary, icon]'));
      expect(fs.files[document.uri], contains('id: button'));

      // Re-parsed in place.
      final reGroups = controller.components.first.record.groups;
      expect(reGroups, hasLength(1));
      expect(reGroups.single.label, 'Main actions');
      expect(reGroups.single.members, ['primary', 'icon']);
    });

    test('rejects a member id that is not a real module (no write)', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithGroups());
      final document = controller.components.first;

      final wrote = await controller.setGroups(document, const [
        ContentGroup(label: 'Bad', members: ['ghost']),
      ]);
      expect(wrote, isFalse);
      expect(fs.writes, isEmpty);
      // The on-disk groups are unchanged.
      expect(controller.components.first.record.groups.single.label,
          'Primary actions');
    });

    test('clearing groups removes the block from disk', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithGroups());
      final document = controller.components.first;

      final wrote = await controller.setGroups(document, const []);
      expect(wrote, isTrue);
      expect(fs.files[document.uri], isNot(contains('groups:')));
      expect(controller.components.first.record.groups, isEmpty);
    });

    test('an unchanged groups list is a no-op', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithGroups());
      final document = controller.components.first;

      final wrote = await controller.setGroups(document, document.record.groups);
      expect(wrote, isFalse);
      expect(fs.writes, isEmpty);
    });
  });

  group('TWE-CTRL-11: site.yaml home.featured (§9 item 4)', () {
    // A live-shaped site.yaml whose home page ships with no featured component:
    // `home.featured:` is present but blank, so the components page renders the
    // flat grid. The blank value must load + validate green and the editor must
    // offer setting it back to a real component id (button/card in the seed).
    const blankFeatured = '''
title: My Site
home:
  hero-md: |
    # Welcome
  featured:
''';

    Map<Uri, String> seedWithBlankFeatured() => {
          ..._seed(),
          _file('/sites/a/content/site.yaml'): blankFeatured,
        };

    test('a blank featured parses as no-featured and validates green',
        () async {
      final (controller, _) =
          await _loaded(_config, seed: seedWithBlankFeatured());
      expect(controller.siteConfig, isNotNull);
      expect(controller.siteConfig!.title, 'My Site');
      expect(controller.siteConfig!.hasFeatured, isFalse);
      expect(controller.siteConfig!.featured, isNull);
      // No error-severity issues — an empty featured is valid.
      expect(controller.siteIssues, isEmpty);
    });

    test('setSiteFeatured writes a component id to disk and re-parses',
        () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithBlankFeatured());
      final siteUri = controller.siteFile!;

      final wrote = await controller.setSiteFeatured('button');
      expect(wrote, isTrue);
      expect(fs.files[siteUri], contains('featured: button'));
      // Other fields are preserved.
      expect(fs.files[siteUri], contains('title: My Site'));
      expect(fs.files[siteUri], contains('# Welcome'));

      // Re-parsed in place: now featured, validated green (button is real).
      expect(controller.siteConfig!.hasFeatured, isTrue);
      expect(controller.siteConfig!.featured, 'button');
      expect(controller.siteIssues, isEmpty);
    });

    test('setSiteFeatured(null) clears the value back to a blank key',
        () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithBlankFeatured());
      await controller.setSiteFeatured('button');
      expect(controller.siteConfig!.hasFeatured, isTrue);

      final cleared = await controller.setSiteFeatured(null);
      expect(cleared, isTrue);
      // The key survives (so the editor can set it again) but the value is gone.
      expect(controller.siteConfig!.hasFeatured, isFalse);
      expect(controller.siteConfig!.featuredSourceLine, isNotNull);
      expect(fs.files[controller.siteFile!], contains('featured:'));
      expect(fs.files[controller.siteFile!], isNot(contains('featured: button')));
    });

    test('setting an unknown component id loads (warning, not error)',
        () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithBlankFeatured());

      final wrote = await controller.setSiteFeatured('ghost');
      expect(wrote, isTrue);
      expect(fs.files[controller.siteFile!], contains('featured: ghost'));
      // An unknown id is a non-fatal warning — the value still loads.
      expect(controller.siteConfig!.featured, 'ghost');
      expect(controller.siteIssues, hasLength(1));
      expect(controller.siteIssues.single.severity, ConfigSeverity.warning);
    });

    test('an unchanged featured value is a no-op', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithBlankFeatured());
      await controller.setSiteFeatured('button');
      fs.writes.clear();

      final again = await controller.setSiteFeatured('button');
      expect(again, isFalse);
      expect(fs.writes, isEmpty);
    });

    test('setSiteFeatured is a no-op when site.yaml has no featured key',
        () async {
      // The default seed's site.yaml is just `title: My Site` (no home block).
      final (controller, fs) = await _loaded(_config);
      expect(controller.siteConfig!.featuredSourceLine, isNull);

      final wrote = await controller.setSiteFeatured('button');
      expect(wrote, isFalse);
      expect(fs.writes, isEmpty);
    });
  });

  group('TWE-CTRL-13: site.yaml detailedComponents (§9 item 7)', () {
    // A site.yaml that already scopes its detailed docs/API to one component.
    const withDetailed = '''
title: My Site
detailedComponents: [button]
''';

    Map<Uri, String> seedWithDetailed() => {
          ..._seed(),
          _file('/sites/a/content/site.yaml'): withDetailed,
        };

    test('a present detailedComponents list parses and is editable', () async {
      final (controller, _) = await _loaded(_config, seed: seedWithDetailed());
      expect(controller.siteConfig!.detailedComponents, ['button']);
      expect(controller.siteConfig!.hasDetailedComponents, isTrue);
      expect(controller.siteIssues, isEmpty);
    });

    test('setSiteDetailedComponents writes the new list and re-parses',
        () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithDetailed());
      final siteUri = controller.siteFile!;

      final wrote =
          await controller.setSiteDetailedComponents(['button', 'card']);
      expect(wrote, isTrue);
      expect(fs.files[siteUri], contains('detailedComponents: [button, card]'));
      expect(fs.files[siteUri], contains('title: My Site'));
      // Re-parsed in place: both ids are real components → validates green.
      expect(controller.siteConfig!.detailedComponents, ['button', 'card']);
      expect(controller.siteIssues, isEmpty);
    });

    test('inserts the key when site.yaml has none yet', () async {
      // The default seed's site.yaml is just `title: My Site` (no key).
      final (controller, fs) = await _loaded(_config);
      expect(controller.siteConfig!.detailedComponents, isNull);

      final wrote = await controller.setSiteDetailedComponents(['button']);
      expect(wrote, isTrue);
      expect(fs.files[controller.siteFile!],
          contains('detailedComponents: [button]'));
      expect(controller.siteConfig!.detailedComponents, ['button']);
    });

    test('an explicit empty list means no detailed components', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithDetailed());
      final wrote = await controller.setSiteDetailedComponents(const []);
      expect(wrote, isTrue);
      expect(fs.files[controller.siteFile!], contains('detailedComponents: []'));
      expect(controller.siteConfig!.detailedComponents, isEmpty);
    });

    test('an unchanged list is a no-op', () async {
      final (controller, fs) =
          await _loaded(_config, seed: seedWithDetailed());
      fs.writes.clear();
      final again = await controller.setSiteDetailedComponents(['button']);
      expect(again, isFalse);
      expect(fs.writes, isEmpty);
    });
  });

  group('TWE-CTRL-12: repo-sourced docs (§9 item 5)', () {
    // A config whose website declares a `sourceRoot` path — the base the
    // repo-sourced README/LICENSE/release are resolved against. A component
    // carries `_generated.source` (its repo root) and modules carry `path:`.
    const configWithSource = '''
version: 1
websites:
  - id: alpha
    paths:
      websiteRoot: "/sites/a"
      sourceRoot: "/src"
    content:
      dir: "{websiteRoot}/content"
''';

    const widgetsComponent = '''
_generated:
  source: pkg/widgets
  generator: gen.dart
id: widgets
name: Widgets
modules:
  - id: primary
    name: Primary
    path: pkg/widgets/primary
  - id: bare
    name: Bare
    path: pkg/widgets/bare
''';

    // Seed: only one component file, plus repo-doc files under {sourceRoot}.
    // The module `primary` has all three; the component has only a README;
    // `bare` has none (so it must surface no repo docs).
    Map<Uri, String> seedWithRepoDocs() => {
          _file('/sites/a/content/components/widgets.yaml'): widgetsComponent,
          _file('/sites/a/content/site.yaml'): 'title: My Site',
          // Component repo root: README only.
          _file('/src/pkg/widgets/README.md'): '# Widgets',
          // Module `primary` repo root: README + LICENSE + release.md.
          _file('/src/pkg/widgets/primary/README.md'): '# Primary',
          _file('/src/pkg/widgets/primary/LICENSE'): 'BSD-3-Clause',
          _file('/src/pkg/widgets/primary/release.md'): '# 1.0.0',
        };

    test('a module with README/LICENSE/release surfaces all three, in order',
        () async {
      final (controller, _) =
          await _loaded(configWithSource, seed: seedWithRepoDocs());
      final docs = controller.repoDocsFor('primary');
      expect(docs.map((d) => d.kind),
          [RepoDocKind.readme, RepoDocKind.license, RepoDocKind.release]);
      expect(docs.map((d) => d.fileName),
          ['README.md', 'LICENSE', 'release.md']);
    });

    test('a component surfaces its own repo root README', () async {
      final (controller, _) =
          await _loaded(configWithSource, seed: seedWithRepoDocs());
      final docs = controller.repoDocsFor('widgets');
      expect(docs.map((d) => d.kind), [RepoDocKind.readme]);
    });

    test('a module whose repo root has no docs surfaces none', () async {
      final (controller, _) =
          await _loaded(configWithSource, seed: seedWithRepoDocs());
      expect(controller.repoDocsFor('bare'), isEmpty);
    });

    test('a website without a sourceRoot has no repo docs (not an error)',
        () async {
      // `_config` declares no `sourceRoot`; resolution is swallowed.
      final (controller, _) = await _loaded(_config);
      expect(controller.error, isNull);
      expect(controller.repoDocsFor('button'), isEmpty);
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

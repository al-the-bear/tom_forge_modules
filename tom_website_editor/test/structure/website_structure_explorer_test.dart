// WebsiteStructureExplorer (§6b): the filesystem-driven content/ tree + a detail
// pane naming the editor a selected file routes to. The view holds no tree
// state; it renders the [WebsiteStructureController]. These widget tests cover
// the disabled state, the rendered tree (sections + grouped copy), file
// selection, and the editor-routing summary (.yaml → YAML, .md → Markdown).
import 'package:flutter/material.dart';
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

/// In-memory [WebsiteContentFs] that infers directories from file paths.
class _FakeFs implements WebsiteContentFs {
  _FakeFs(this.files);

  final Map<Uri, String> files;

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
  Future<void> write(Uri uri, String content) async => files[uri] = content;

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

Map<Uri, String> _seed() => {
      Uri.file('/sites/a/content/site.yaml'): 'home: {}',
      Uri.file('/sites/a/content/components/button.yaml'): 'id: button',
      Uri.file('/sites/a/content/copy/home.md'): '# home',
      Uri.file('/sites/a/content/copy/auth_component.md'): '# auth',
      Uri.file('/sites/a/content/pages/about.md'): '# about',
    };

Future<WebsiteStructureController> _loaded({required String activeId}) async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  editor.selectWebsite(activeId);
  final controller =
      WebsiteStructureController(editor: editor, fileSystem: _FakeFs(_seed()));
  await controller.refresh();
  return controller;
}

Future<void> _pump(WidgetTester tester, WebsiteStructureExplorer view) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: view.buildMain)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TWE-STRUCT-01: disabled without a content block',
      (tester) async {
    final controller = await _loaded(activeId: 'beta');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    expect(find.textContaining('no "content:" block'), findsOneWidget);
  });

  testWidgets('TWE-STRUCT-02: renders the content/ tree', (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    expect(find.text('site.yaml'), findsOneWidget);
    expect(find.text('components'), findsOneWidget);
    expect(find.text('button.yaml'), findsOneWidget);
    // Copy is grouped by §16: the component group and the home file appear.
    expect(find.text('auth'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('TWE-STRUCT-03: selecting a yaml file shows YAML routing',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    await tester.tap(find.text('button.yaml'));
    await tester.pumpAndSettle();

    expect(find.textContaining('the YAML editor'), findsOneWidget);
  });

  testWidgets('TWE-STRUCT-04: selecting a md file shows Markdown routing',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    await tester.tap(find.text('about.md'));
    await tester.pumpAndSettle();

    expect(find.textContaining('the Markdown editor'), findsOneWidget);
  });

  // TWE-STRUCT-05: the §9 search box narrows the visible tree to matches.
  testWidgets('TWE-STRUCT-05: the filter narrows the visible nodes',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));
    expect(find.text('site.yaml'), findsOneWidget);
    expect(find.text('about.md'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'button');
    await tester.pumpAndSettle();

    expect(find.text('button.yaml'), findsOneWidget);
    expect(find.text('components'), findsOneWidget);
    expect(find.text('site.yaml'), findsNothing);
    expect(find.text('about.md'), findsNothing);
    expect(find.text('pages'), findsNothing);
  });

  // TWE-STRUCT-06: the per-directory new-file affordance creates a file.
  testWidgets('TWE-STRUCT-06: new-file affordance creates a file',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    await tester.tap(find.byTooltip('New file in components'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'hero.yaml');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('hero.yaml'), findsOneWidget);
  });

  // TWE-STRUCT-07: the per-file Rename affordance renames the file.
  testWidgets('TWE-STRUCT-07: rename affordance renames a file',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'button.yaml'),
      matching: find.byIcon(Icons.more_vert),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'pressable.yaml');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('pressable.yaml'), findsOneWidget);
    expect(find.text('button.yaml'), findsNothing);
  });

  // TWE-STRUCT-08: the per-file Delete affordance removes the file (confirmed).
  testWidgets('TWE-STRUCT-08: delete affordance removes a file',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    await _pump(tester, WebsiteStructureExplorer(controller: controller));

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'button.yaml'),
      matching: find.byIcon(Icons.more_vert),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('button.yaml'), findsNothing);
  });

  // TWE-STRUCT-09: tapping a file node opens its backing file through the
  // onOpenFile seam — a yaml file, a page .md, and a grouped copy/*.md.
  testWidgets('TWE-STRUCT-09: tapping a file node opens it', (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    final opened = <Uri>[];
    await _pump(
      tester,
      WebsiteStructureExplorer(controller: controller, onOpenFile: opened.add),
    );

    await tester.tap(find.text('button.yaml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('about.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home')); // copy/home.md (grouped §16)
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.file('/sites/a/content/components/button.yaml'),
      Uri.file('/sites/a/content/pages/about.md'),
      Uri.file('/sites/a/content/copy/home.md'),
    ]);
  });

  // TWE-STRUCT-10: the detail-pane Open-in-editor button re-opens the selected
  // file through the same seam.
  testWidgets('TWE-STRUCT-10: detail pane Open-in-editor reopens the file',
      (tester) async {
    final controller = await _loaded(activeId: 'alpha');
    final opened = <Uri>[];
    await _pump(
      tester,
      WebsiteStructureExplorer(controller: controller, onOpenFile: opened.add),
    );

    // Tap opens once; the detail-pane button opens it a second time.
    await tester.tap(find.text('button.yaml'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Open in editor'));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.file('/sites/a/content/components/button.yaml'),
      Uri.file('/sites/a/content/components/button.yaml'),
    ]);
  });
}

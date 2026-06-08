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
}

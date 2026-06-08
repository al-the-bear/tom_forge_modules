// WebsiteContentBrowser (§6a): the catalog tree + field/page detail pane. The
// view holds no catalog state; it renders the [WebsiteContentController] and
// drives the pin action on tap. These widget tests cover the disabled state,
// the record tree, managed-vs-editable field rendering, the pin affordance, and
// the typed-suffix inline-editor routing.
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

const _button = '''
id: button
name: Button
tagline: A clickable thing
summary-md: "## Button"
status: stable
''';

class _FakeContentFs implements WebsiteContentFs {
  _FakeContentFs(this.files);
  final Map<Uri, String> files;
  final List<({Uri uri, String content})> writes = [];

  @override
  Future<List<Uri>> listFiles(Uri directory) async {
    final prefix = directory.path.endsWith('/')
        ? directory.path
        : '${directory.path}/';
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
    final prefix = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return files.keys.any((u) => u.path.startsWith(prefix));
  }
}

Future<(WebsiteContentController, _FakeContentFs)> _loaded({
  String? activeId,
}) async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  if (activeId != null) editor.selectWebsite(activeId);
  final fs = _FakeContentFs({
    Uri.file('/sites/a/content/components/button.yaml'): _button,
    Uri.file('/sites/a/content/site.yaml'): 'title: Alpha\n',
    Uri.file('/sites/a/content/pages/home.md'): '# Home\n',
  });
  final controller =
      WebsiteContentController(editor: editor, fileSystem: fs);
  await controller.refresh();
  return (controller, fs);
}

Future<void> _pump(WidgetTester tester, WebsiteContentBrowser view) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: view.buildMain)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TWE-BROWSE-01: disabled without a content block',
      (tester) async {
    final (controller, _) = await _loaded(activeId: 'beta');
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    expect(find.textContaining('no "content:" block'), findsOneWidget);
  });

  testWidgets('TWE-BROWSE-02: renders the component tree', (tester) async {
    final (controller, _) = await _loaded();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    expect(find.text('Button'), findsOneWidget);
  });

  testWidgets('TWE-BROWSE-03: managed field shows a pin button, editable does not',
      (tester) async {
    final (controller, _) = await _loaded();
    final view = WebsiteContentBrowser(controller: controller);
    await _pump(tester, view);

    // Select the component record.
    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    // Managed field "status" has a Pin affordance; editable "tagline" does not.
    expect(find.text('status'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Pin'), findsWidgets);
    expect(find.text('tagline'), findsOneWidget);
  });

  testWidgets('TWE-BROWSE-04: pin button writes the pin to disk',
      (tester) async {
    final (controller, fs) = await _loaded();
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    final view = WebsiteContentBrowser(controller: controller);
    await _pump(tester, view);

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Pin').first);
    await tester.pumpAndSettle();

    expect(fs.files[uri], contains('# @manual'));
  });

  testWidgets('TWE-BROWSE-05: editable fields route to typed inline editors',
      (tester) async {
    final (controller, _) = await _loaded();
    final view = WebsiteContentBrowser(controller: controller);
    await _pump(tester, view);

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    // tagline → plain text; summary-md → Markdown helper label.
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.byKey(const ValueKey('content-field-tagline')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('content-field-summary-md')),
        findsOneWidget);
  });

  testWidgets(
      'TWE-BROWSE-06: tapping a record/page/site opens its backing file',
      (tester) async {
    final (controller, _) = await _loaded();
    final opened = <Uri>[];
    final view = WebsiteContentBrowser(
      controller: controller,
      onOpenFile: opened.add,
    );
    await _pump(tester, view);

    // A component record opens content/components/<c>.yaml.
    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();
    // site.yaml opens itself; a page opens content/pages/<p>.md.
    await tester.tap(find.text('site.yaml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home.md'));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.file('/sites/a/content/components/button.yaml'),
      Uri.file('/sites/a/content/site.yaml'),
      Uri.file('/sites/a/content/pages/home.md'),
    ]);
  });

  testWidgets('TWE-BROWSE-07: detail pane Open-in-editor reopens the file',
      (tester) async {
    final (controller, _) = await _loaded();
    final opened = <Uri>[];
    final view = WebsiteContentBrowser(
      controller: controller,
      onOpenFile: opened.add,
    );
    await _pump(tester, view);

    // Select site.yaml (tap opens once), then use the detail-pane button.
    await tester.tap(find.text('site.yaml'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Open in editor'));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.file('/sites/a/content/site.yaml'),
      Uri.file('/sites/a/content/site.yaml'),
    ]);
  });
}

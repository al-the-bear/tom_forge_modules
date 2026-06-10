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
      # This suite exercises the typed-suffix inline editor on the `summary-md`
      # record field, so it configures that suffixed field explicitly rather than
      # depending on the canonical default (which lists the unsuffixed §16
      # copy-file front-matter keys `tagline`/`summary`/`enables`; forge web todo 14).
      editableFields: [tagline, summary-md]
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

// A component carrying a `_generated` provenance block, a pinned field, and a
// managed field whose value contains a §3 placeholder — used by the step-10
// provenance/placeholder-hint tests.
// Kept short so every field row fits the default 800x600 test viewport (the
// detail pane is a lazy ListView — off-screen rows are not built).
const _buttonGen = '''
name: Button
status: stable
version: "1.0.0"  # @manual
docsUrl: "{websiteRoot}/docs/button"
_generated:
  by: tom-generate
  at: 2026-06-01T10:00:00Z
''';

// Two components with modules, used by the tree-pruning (2a) and attribute
// search (2b) tests. Each module carries a managed `color` field so the
// attribute search has cross-module hits to aggregate.
const _buttonTree = '''
id: button
name: Button
modules:
  - id: primary
    name: Primary
    color: blue
  - id: secondary
    name: Secondary
    color: gray
''';

const _cardTree = '''
id: card
name: Card
modules:
  - id: header
    name: Header
    color: white
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

  @override
  Future<void> delete(Uri uri) async {
    files.remove(uri);
    final prefix = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    files.removeWhere((u, _) => u.path.startsWith(prefix));
  }

  @override
  Future<void> rename(Uri from, Uri to) async {
    final content = files.remove(from);
    if (content != null) files[to] = content;
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

Future<(WebsiteContentController, _FakeContentFs)> _loadedGen() async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  final fs = _FakeContentFs({
    Uri.file('/sites/a/content/components/button.yaml'): _buttonGen,
  });
  final controller =
      WebsiteContentController(editor: editor, fileSystem: fs);
  await controller.refresh();
  return (controller, fs);
}

Future<(WebsiteContentController, _FakeContentFs)> _loadedTree() async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  final fs = _FakeContentFs({
    Uri.file('/sites/a/content/components/button.yaml'): _buttonTree,
    Uri.file('/sites/a/content/components/card.yaml'): _cardTree,
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

  testWidgets('TWE-BROWSE-08: editing a scalar field persists on submit',
      (tester) async {
    final (controller, fs) = await _loaded();
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    final view = WebsiteContentBrowser(controller: controller);
    await _pump(tester, view);

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('content-field-tagline')), 'Pressable');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(fs.files[uri], contains('tagline: Pressable'));
    // The edit round-trips: re-parsing keeps the rest of the document intact.
    expect(fs.files[uri], contains('id: button'));
    expect(fs.files[uri], contains('summary-md:'));
  });

  testWidgets('TWE-BROWSE-09: a managed field has no inline editor',
      (tester) async {
    final (controller, _) = await _loaded();
    final view = WebsiteContentBrowser(controller: controller);
    await _pump(tester, view);

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    // The managed "status" field renders read-only (a Pin affordance), never an
    // editable text field keyed for it.
    expect(find.text('status'), findsOneWidget);
    expect(find.byKey(const ValueKey('content-field-status')), findsNothing);
  });

  testWidgets('TWE-BROWSE-10: an -md field routes to the full editor, not inline',
      (tester) async {
    final (controller, _) = await _loaded();
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    final opened = <Uri>[];
    final view = WebsiteContentBrowser(
      controller: controller,
      onOpenFile: opened.add,
    );
    await _pump(tester, view);

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();
    opened.clear(); // ignore the open triggered by selecting the record

    // The -md field is not an inline TextField; it offers an open-in-editor
    // affordance that routes the backing file to the full editor.
    final mdField = find.byKey(const ValueKey('content-field-summary-md'));
    expect(
        find.descendant(of: mdField, matching: find.byType(TextField)),
        findsNothing);
    await tester.tap(find.descendant(
        of: mdField, matching: find.byType(OutlinedButton)));
    await tester.pumpAndSettle();

    expect(opened, [uri]);
  });

  // TWE-BROWSE-11: the §9 search box narrows the visible catalog to matches.
  testWidgets('TWE-BROWSE-11: the filter narrows the visible nodes',
      (tester) async {
    final (controller, _) = await _loaded();
    await _pump(tester, WebsiteContentBrowser(controller: controller));
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('home.md'), findsOneWidget);
    expect(find.text('site.yaml'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('tree-filter')), 'home');
    await tester.pumpAndSettle();

    expect(find.text('home.md'), findsOneWidget);
    expect(find.text('Button'), findsNothing);
    expect(find.text('site.yaml'), findsNothing);
  });

  // TWE-BROWSE-12: a managed field surfaces the record's `_generated`
  // provenance as a badge whose tooltip names the generator.
  testWidgets('TWE-BROWSE-12: managed field renders a provenance badge',
      (tester) async {
    final (controller, _) = await _loadedGen();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('provenance-status'));
    expect(badge, findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: badge, matching: find.byType(Tooltip)));
    expect(tooltip.message, contains('tom-generate'));
  });

  // TWE-BROWSE-13: a value containing a §3 placeholder is visually
  // distinguished with a "resolves at generate time" hint.
  testWidgets('TWE-BROWSE-13: a placeholder value renders a generate-time hint',
      (tester) async {
    final (controller, _) = await _loadedGen();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    final hint = find.byKey(const ValueKey('placeholder-hint-docsUrl'));
    expect(hint, findsOneWidget);
    expect(
        find.descendant(
            of: hint, matching: find.textContaining('resolves at generate time')),
        findsOneWidget);
  });

  // TWE-BROWSE-14: a pinned field's badge carries a pin-state tooltip.
  testWidgets('TWE-BROWSE-14: a pinned field badge carries a pin-state tooltip',
      (tester) async {
    final (controller, _) = await _loadedGen();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('badge-version'));
    expect(badge, findsOneWidget);
    final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: badge, matching: find.byType(Tooltip)));
    expect(tooltip.message!.toLowerCase(), contains('manual'));
  });

  // TWE-BROWSE-15: a pinned field shows an Unpin affordance that removes the
  // `# @manual` marker from disk; a managed field shows none.
  testWidgets('TWE-BROWSE-15: unpin button reverts a pinned field to managed',
      (tester) async {
    final (controller, fs) = await _loadedGen();
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    // The pinned `version` field has an Unpin button; the managed `status`
    // field has none (it offers Pin instead).
    final unpin = find.byKey(const ValueKey('unpin-version'));
    expect(unpin, findsOneWidget);
    expect(find.byKey(const ValueKey('unpin-status')), findsNothing);

    await tester.tap(unpin);
    await tester.pumpAndSettle();

    // The marker is gone from disk; the value itself is kept.
    expect(fs.files[uri], isNot(contains('# @manual')));
    expect(fs.files[uri], contains('version: "1.0.0"'));

    // After the re-parse the Unpin affordance is gone (field is managed again).
    expect(find.byKey(const ValueKey('unpin-version')), findsNothing);
  });

  // TWE-BROWSE-16: the tree filter prunes by record name (contains, case-
  // insensitive) — a matched module keeps its component ancestor but hides
  // sibling modules and non-matching components.
  testWidgets('TWE-BROWSE-16: tree filter prunes to matching modules',
      (tester) async {
    final (controller, _) = await _loadedTree();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    // Everything is visible before filtering.
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Secondary'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Header'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('tree-filter')), 'primary');
    await tester.pumpAndSettle();

    // Only Primary matches; its Button ancestor stays as a container, but the
    // sibling module and the other component are pruned.
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Button'), findsOneWidget);
    expect(find.text('Secondary'), findsNothing);
    expect(find.text('Card'), findsNothing);
    expect(find.text('Header'), findsNothing);
  });

  // TWE-BROWSE-17: matching a component name reveals its full subtree.
  testWidgets('TWE-BROWSE-17: matching a component reveals its whole subtree',
      (tester) async {
    final (controller, _) = await _loadedTree();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.enterText(find.byKey(const ValueKey('tree-filter')), 'card');
    await tester.pumpAndSettle();

    // Card matches by name, so its Header module shows even though "header"
    // does not contain "card"; the Button subtree is pruned.
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Button'), findsNothing);
    expect(find.text('Primary'), findsNothing);
  });

  // TWE-BROWSE-18: the attribute name search aggregates matching fields across
  // every visible module, each labelled with its record path.
  testWidgets('TWE-BROWSE-18: attribute name search aggregates across modules',
      (tester) async {
    final (controller, _) = await _loadedTree();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.enterText(
        find.byKey(const ValueKey('attr-name-search')), 'color');
    await tester.pumpAndSettle();

    // All three modules expose a `color` field; each is a distinct hit.
    expect(find.byKey(const ValueKey('attr-hit-primary-color')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('attr-hit-secondary-color')), findsOneWidget);
    expect(find.byKey(const ValueKey('attr-hit-header-color')), findsOneWidget);
    expect(find.text('Button › Primary'), findsOneWidget);
    expect(find.text('Card › Header'), findsOneWidget);
  });

  // TWE-BROWSE-19: the attribute value search narrows hits by value.
  testWidgets('TWE-BROWSE-19: attribute value search narrows by value',
      (tester) async {
    final (controller, _) = await _loadedTree();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    await tester.enterText(
        find.byKey(const ValueKey('attr-value-search')), 'blue');
    await tester.pumpAndSettle();

    // Only Primary's color is blue.
    expect(find.byKey(const ValueKey('attr-hit-primary-color')), findsOneWidget);
    expect(find.byKey(const ValueKey('attr-hit-secondary-color')), findsNothing);
    expect(find.byKey(const ValueKey('attr-hit-header-color')), findsNothing);
  });

  // TWE-BROWSE-20: the attribute search is scoped to the records the tree
  // currently shows — filtering the tree first narrows the attribute hits.
  testWidgets('TWE-BROWSE-20: attribute search is scoped to found modules',
      (tester) async {
    final (controller, _) = await _loadedTree();
    await _pump(tester, WebsiteContentBrowser(controller: controller));

    // Restrict the tree to Primary, then search attribute names.
    await tester.enterText(
        find.byKey(const ValueKey('tree-filter')), 'primary');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('attr-name-search')), 'color');
    await tester.pumpAndSettle();

    // Only Primary's color is in scope; the hidden modules contribute nothing.
    expect(find.byKey(const ValueKey('attr-hit-primary-color')), findsOneWidget);
    expect(find.byKey(const ValueKey('attr-hit-secondary-color')), findsNothing);
    expect(find.byKey(const ValueKey('attr-hit-header-color')), findsNothing);
  });
}

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

// A component carrying the §9 item-1 `groups:` block: four modules, two of which
// are grouped under "Primary actions", one under "Helpers", leaving `badge`
// ungrouped (it falls under "Other modules"). Used by the groups-editor tests.
const _buttonGroups = '''
id: button
name: Button
groups:
  - label: Primary actions
    members: [primary, secondary]
  - label: Helpers
    members: [icon]
modules:
  - id: primary
    name: Primary
  - id: secondary
    name: Secondary
  - id: icon
    name: Icon
  - id: badge
    name: Badge
''';

// As above but one group lists a stale member id (`ghost`) that resolves to no
// module — used to exercise the unknown-member warning.
const _buttonGroupsStale = '''
id: button
name: Button
groups:
  - label: Primary actions
    members: [primary, ghost]
modules:
  - id: primary
    name: Primary
  - id: secondary
    name: Secondary
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

Future<(WebsiteContentController, _FakeContentFs)> _loadedGroups(
    String component) async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  final fs = _FakeContentFs({
    Uri.file('/sites/a/content/components/button.yaml'): component,
  });
  final controller =
      WebsiteContentController(editor: editor, fileSystem: fs);
  await controller.refresh();
  return (controller, fs);
}

Future<(WebsiteContentController, _FakeContentFs)> _loadedSiteCopy() async {
  final editor = WebsiteEditorController(configReader: () async => _config);
  await editor.load();
  final fs = _FakeContentFs({
    Uri.file('/sites/a/content/components/button.yaml'): _button,
    Uri.file('/sites/a/content/site.yaml'): 'title: Alpha\n',
    Uri.file('/sites/a/content/copy/home.md'): '# Home\n',
    Uri.file('/sites/a/content/copy/news.md'): '# News\n',
    // A per-entity copy file is loaded but is NOT site-level copy.
    Uri.file('/sites/a/content/copy/button_component.md'): '# Button\n',
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

/// Pumps the browser in a tall viewport so the lazily-built detail-pane
/// ListView materializes the whole groups editor (the section sits below the
/// component's fields and would otherwise be off-screen at the default 600px).
Future<void> _pumpTall(WidgetTester tester, WebsiteContentBrowser view) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

  // TWE-BROWSE-21: the §9 item-1 groups editor renders existing groups, their
  // member chips, and the "Other modules" bucket for ungrouped modules.
  testWidgets('TWE-BROWSE-21: renders the groups editor for a component',
      (tester) async {
    final (controller, _) = await _loadedGroups(_buttonGroups);
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    // The component carries modules, so its tree node is an ExpansionTile;
    // select the component record itself via its "Fields" tile.
    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    expect(find.text('Module groups'), findsOneWidget);
    expect(find.byKey(const ValueKey('group-card-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-member-0-primary')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('group-member-0-secondary')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-member-1-icon')), findsOneWidget);
    // `badge` is in no group → "Other modules".
    expect(find.byKey(const ValueKey('groups-other-modules')), findsOneWidget);
    expect(find.byKey(const ValueKey('other-module-badge')), findsOneWidget);
  });

  // TWE-BROWSE-22: the Add-group button appends a new group and persists it.
  testWidgets('TWE-BROWSE-22: add group writes a new group to disk',
      (tester) async {
    final (controller, fs) = await _loadedGroups(_buttonGroups);
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-group')));
    await tester.pumpAndSettle();

    expect(fs.files[uri], contains('New group'));
    expect(find.byKey(const ValueKey('group-card-2')), findsOneWidget);
  });

  // TWE-BROWSE-23: renaming a group label persists on submit.
  testWidgets('TWE-BROWSE-23: renaming a group label persists',
      (tester) async {
    final (controller, fs) = await _loadedGroups(_buttonGroups);
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('group-label-0')),
            matching: find.byType(TextField)),
        'Calls to action');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(fs.files[uri], contains('Calls to action'));
    // The original label is gone; the rest of the block is intact.
    expect(fs.files[uri], isNot(contains('Primary actions')));
    expect(fs.files[uri], contains('Helpers'));
  });

  // TWE-BROWSE-24: assigning a module via the Add-module menu writes it into
  // the group's members.
  testWidgets('TWE-BROWSE-24: assign a module via the add-member menu',
      (tester) async {
    final (controller, fs) = await _loadedGroups(_buttonGroups);
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('group-add-member-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-assign-0-badge')));
    await tester.pumpAndSettle();

    expect(fs.files[uri], contains('members: [primary, secondary, badge]'));
    expect(find.byKey(const ValueKey('group-member-0-badge')), findsOneWidget);
  });

  // TWE-BROWSE-25: removing a member chip writes the removal.
  testWidgets('TWE-BROWSE-25: removing a member chip persists',
      (tester) async {
    final (controller, fs) = await _loadedGroups(_buttonGroups);
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    await tester.tap(
        find.byKey(const ValueKey('group-member-remove-0-primary')));
    await tester.pumpAndSettle();

    expect(fs.files[uri], contains('members: [secondary]'));
    expect(find.byKey(const ValueKey('group-member-0-primary')), findsNothing);
    // `primary` is now ungrouped, so it surfaces under "Other modules".
    expect(find.byKey(const ValueKey('other-module-primary')), findsOneWidget);
  });

  // TWE-BROWSE-26: the move-down control reorders groups and persists.
  testWidgets('TWE-BROWSE-26: reordering groups persists the new order',
      (tester) async {
    final (controller, fs) = await _loadedGroups(_buttonGroups);
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('group-down-0')));
    await tester.pumpAndSettle();

    final written = fs.files[uri]!;
    // "Helpers" now precedes "Primary actions" in the serialized block.
    expect(written.indexOf('Helpers'),
        lessThan(written.indexOf('Primary actions')));
  });

  // TWE-BROWSE-27: deleting a group removes it from disk and the UI.
  testWidgets('TWE-BROWSE-27: deleting a group persists the removal',
      (tester) async {
    final (controller, fs) = await _loadedGroups(_buttonGroups);
    final uri = Uri.file('/sites/a/content/components/button.yaml');
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('group-delete-1')));
    await tester.pumpAndSettle();

    expect(fs.files[uri], isNot(contains('Helpers')));
    expect(find.byKey(const ValueKey('group-card-1')), findsNothing);
    // `icon` was the deleted group's only member → now ungrouped.
    expect(find.byKey(const ValueKey('other-module-icon')), findsOneWidget);
  });

  // TWE-BROWSE-28: a stale member id (no matching module) raises the unknown-
  // member warning naming the offending id.
  testWidgets('TWE-BROWSE-28: a stale member id raises the unknown warning',
      (tester) async {
    final (controller, _) = await _loadedGroups(_buttonGroupsStale);
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    final warning = find.byKey(const ValueKey('groups-unknown-warning'));
    expect(warning, findsOneWidget);
    expect(find.descendant(of: warning, matching: find.textContaining('ghost')),
        findsOneWidget);
  });

  // TWE-BROWSE-29: a component with no modules and no groups shows no groups
  // editor at all.
  testWidgets('TWE-BROWSE-29: a module-less component has no groups editor',
      (tester) async {
    final (controller, _) = await _loaded();
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    expect(find.text('Module groups'), findsNothing);
  });

  // TWE-BROWSE-30: site-level copy files (home.md, news.md) appear together in
  // the tree as a "Site copy" group, distinct from per-entity copy files.
  testWidgets('TWE-BROWSE-30: site-level copy is surfaced in the tree',
      (tester) async {
    final (controller, _) = await _loadedSiteCopy();
    await _pumpTall(tester, WebsiteContentBrowser(controller: controller));

    expect(find.byKey(const ValueKey('site-copy-home.md')), findsOneWidget);
    expect(find.byKey(const ValueKey('site-copy-news.md')), findsOneWidget);
    // The "Site copy" subtitle labels them as editorial copy.
    expect(find.text('Site copy'), findsNWidgets(2));
    // The per-entity component copy file is not surfaced as site-level copy.
    expect(find.byKey(const ValueKey('site-copy-button_component.md')),
        findsNothing);
  });

  // TWE-BROWSE-31: tapping a site-level copy file opens it through the open
  // seam (routes to tom_md_editor by its .md suffix).
  testWidgets('TWE-BROWSE-31: tapping news.md opens it through the seam',
      (tester) async {
    final (controller, _) = await _loadedSiteCopy();
    final opened = <Uri>[];
    final view = WebsiteContentBrowser(
      controller: controller,
      onOpenFile: opened.add,
    );
    await _pumpTall(tester, view);

    await tester.tap(find.byKey(const ValueKey('site-copy-news.md')));
    await tester.pumpAndSettle();

    expect(opened, [Uri.file('/sites/a/content/copy/news.md')]);
    // The detail pane names the site-level copy routing target.
    expect(find.textContaining('Site-level copy'), findsOneWidget);
  });
}

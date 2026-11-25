// The explorer's opt-in features (D36 §2–§4 of Webwork's Workspace
// browser): ordered filter rules with presets, the hidden count, the root
// switcher kept through the kit's state store, and the bounded walk; and,
// with none of them configured, Tom Forge's explorer as it was.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

class _Host implements ForgeEditorHost {
  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {}

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

TomMemoryFileSystem _files(Map<String, String> seed) =>
    TomMemoryFileSystem(seed: seed);

ForgeFileExplorerView _view(
  TomFileSystem files, {
  ForgeFilter? filter,
  List<ForgeFilterPreset>? filterPresets,
  bool rootSwitcher = false,
  ForgeStateStore? stateStore,
  int walkLimit = forgeExplorerWalkLimit,
}) => ForgeFileExplorerView(
  fileSystem: files,
  openFile: (uri, {line, column}) {},
  rootUri: Uri.directory('/w'),
  filter: filter,
  filterPresets: filterPresets,
  rootSwitcher: rootSwitcher,
  stateStore: stateStore,
  walkLimit: walkLimit,
);

Future<void> _show(WidgetTester tester, ForgeView view, {Key? key}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          key: key,
          width: 300,
          height: 500,
          child: Builder(builder: view.buildMain),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _openFilterMenu(WidgetTester tester) async {
  await tester.tap(_key('forge-explorer-filter-menu'));
  await tester.pumpAndSettle();
}

Future<void> _tapOpen(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without filter, presets or root switcher the explorer is '
      'Forge\'s: no header, no footer, dot entries left out', (tester) async {
    final files = _files({
      '/w/.env': 'A=1\n',
      '/w/README.md': '#\n',
      '/w/lib/a.dart': '',
    });
    final view = _view(files);
    expect(view.filtering, isFalse);
    await _show(tester, view);

    expect(_key('forge-explorer-header'), findsNothing);
    expect(_key('forge-explorer-footer'), findsNothing);
    expect(_key('forge-explorer-hidden-count'), findsNothing);
    expect(find.text('.env'), findsNothing);
    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('a.dart'), findsNothing);
    await _tapOpen(tester, 'lib');
    expect(find.text('a.dart'), findsOneWidget);
  });

  testWidgets('rules hide entries, the last match decides, and a folder '
      'shows when anything below it does', (tester) async {
    final files = _files({
      '/w/README.md': '#\n',
      '/w/lib/a.dart': '',
      '/w/doc/x.md': '',
      '/w/doc/secret.md': '',
    });
    await _show(
      tester,
      _view(
        files,
        filter: ForgeFilter([
          ForgeGlobRule('**', include: false),
          ForgeGlobRule('**/*.md', include: true),
          ForgeGlobRule('**/secret.md', include: false),
        ]),
      ),
    );

    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('doc'), findsOneWidget);
    expect(find.text('lib'), findsNothing);
    // lib, lib/a.dart and doc/secret.md.
    expect(find.text('3 hidden'), findsOneWidget);
    // doc carries its own count.
    expect(_key('forge-explorer-hidden-in:/w/doc'), findsOneWidget);
    await _tapOpen(tester, 'doc');
    expect(find.text('x.md'), findsOneWidget);
    expect(find.text('secret.md'), findsNothing);

    // The same rules with the exclusion before the inclusion: the inclusion
    // matches last and shows secret.md.
    await _show(
      tester,
      _view(
        files,
        filter: ForgeFilter([
          ForgeGlobRule('**', include: false),
          ForgeGlobRule('**/secret.md', include: false),
          ForgeGlobRule('**/*.md', include: true),
        ]),
      ),
      key: const ValueKey('again'),
    );
    await _tapOpen(tester, 'doc');
    expect(find.text('secret.md'), findsOneWidget);
    expect(find.text('2 hidden'), findsOneWidget);
  });

  testWidgets('the presets of tom_file_session switch from the filter '
      'button; the hidden count follows', (tester) async {
    final files = _files({
      '/w/.gitignore': 'build/\n',
      '/w/.git/config': '',
      '/w/build/out.txt': '',
      '/w/notes.md': '',
      '/w/image.png': '',
      '/w/lib/a.dart': '',
    });
    await _show(tester, _view(files, filterPresets: ForgeBuiltInPresets.all));

    // All files: hidden and gitignored entries hidden.
    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('image.png'), findsOneWidget);
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('.gitignore'), findsNothing);
    expect(find.text('.git'), findsNothing);
    expect(find.text('build'), findsNothing);
    expect(find.text('3 hidden'), findsOneWidget);

    await _openFilterMenu(tester);
    for (final preset in ForgeBuiltInPresets.all) {
      expect(_key('forge-explorer-preset:${preset.name}'), findsOneWidget);
    }
    await tester.tap(_key('forge-explorer-preset:Text files'));
    await tester.pumpAndSettle();

    expect(find.text('image.png'), findsNothing);
    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('4 hidden'), findsOneWidget);

    // Back to All files.
    await _openFilterMenu(tester);
    await tester.tap(
      _key('forge-explorer-preset:${ForgeBuiltInPresets.allFilesName}'),
    );
    await tester.pumpAndSettle();
    expect(find.text('image.png'), findsOneWidget);
    expect(find.text('3 hidden'), findsOneWidget);
  });

  testWidgets('the hidden count lists what is hidden and by which rule, and '
      'shows the hidden entries for a while, dimmed', (tester) async {
    final files = _files({'/w/.env': 'A=1\n', '/w/notes.md': ''});
    await _show(tester, _view(files, filterPresets: ForgeBuiltInPresets.all));
    expect(find.text('.env'), findsNothing);

    await tester.tap(_key('forge-explorer-hidden-count'));
    await tester.pumpAndSettle();
    expect(_key('forge-explorer-hidden-list'), findsOneWidget);
    expect(find.text('.env'), findsOneWidget);
    expect(find.text('hidden entries: hide'), findsOneWidget);
    await tester.tap(_key('forge-explorer-hidden-toggle'));
    await tester.pumpAndSettle();

    expect(find.text('.env'), findsOneWidget);
    expect(find.text('1 hidden, shown'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('.env'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('notes.md'), matching: find.byType(Opacity)),
      findsNothing,
    );

    // The filter menu switches it back.
    await _openFilterMenu(tester);
    await tester.tap(_key('forge-explorer-show-hidden'));
    await tester.pumpAndSettle();
    expect(find.text('.env'), findsNothing);
    expect(find.text('1 hidden'), findsOneWidget);
  });

  testWidgets('Edit rules… edits the rules as text; a line it cannot read '
      'refuses Apply', (tester) async {
    final files = _files({'/w/notes.md': '', '/w/lib/a.dart': ''});
    await _show(tester, _view(files, filterPresets: ForgeBuiltInPresets.all));
    expect(find.text('lib'), findsOneWidget);

    await _openFilterMenu(tester);
    await tester.tap(_key('forge-explorer-edit-rules'));
    await tester.pumpAndSettle();
    final field = _key('forge-explorer-rules-field');
    expect(
      tester.widget<TextField>(field).controller!.text,
      forgeExplorerRulesText(ForgeBuiltInPresets.allFiles.filter),
    );

    await tester.enterText(field, 'shout: loud');
    await tester.pump();
    expect(find.textContaining('unknown rule'), findsOneWidget);
    expect(
      tester.widget<TextButton>(_key('forge-explorer-rules-apply')).onPressed,
      isNull,
    );

    await tester.enterText(field, 'hidden: hide\nexclude extensions: dart');
    await tester.pump();
    await tester.tap(_key('forge-explorer-rules-apply'));
    await tester.pumpAndSettle();
    // No rule speaks to the folder lib; its Dart file is hidden.
    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('1 hidden'), findsOneWidget);
    await _tapOpen(tester, 'lib');
    expect(find.text('a.dart'), findsNothing);
  });

  test('the rules text reads what describe() writes, and the short forms', () {
    final filter = ForgeFilter([
      ForgeGlobRule('**', include: false),
      ForgeExtensionRule(['md', 'yaml'], include: true),
      const ForgeHiddenRule(show: false),
      const ForgeGitignoredRule(show: true),
      const ForgeTodoSiblingsRule(show: false),
    ]);
    final parsed = forgeExplorerParseRules(forgeExplorerRulesText(filter));
    expect(parsed.problems, isEmpty);
    expect(parsed.filter!.encode(), filter.encode());

    final short = forgeExplorerParseRules(
      '# a comment\ninclude: **/*.md\n\nhidden: show\ntodo siblings: hide',
    );
    expect(short.filter!.encode(), [
      {'rule': 'glob', 'glob': '**/*.md', 'include': true},
      {'rule': 'hidden', 'show': true},
      {'rule': 'todoSiblings', 'show': false},
    ]);
    expect(forgeExplorerParseRules('hidden: maybe').problems, [
      'Line 1: say "show" or "hide"',
    ]);
  });

  testWidgets('roots registered, switched and removed; the roots, the root '
      'shown and the filter choice are kept through the state store', (
    tester,
  ) async {
    final files = _files({'/w/a.txt': '', '/x/b.txt': '', '/x/c.png': ''});
    final store = ForgeMemoryStateStore();
    ForgeFileExplorerView make() => _view(
      files,
      rootSwitcher: true,
      filterPresets: ForgeBuiltInPresets.all,
      stateStore: store,
    );
    await _show(tester, make());
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('w'), findsOneWidget);

    // A path that is no folder is refused.
    Future<void> addFolder(String path) async {
      await tester.tap(_key('forge-explorer-root-menu'));
      await tester.pumpAndSettle();
      expect(_key('forge-explorer-remove-root'), findsNothing);
      await tester.tap(_key('forge-explorer-add-root'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), path);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    await addFolder('/nowhere');
    expect(find.text('No folder at /nowhere'), findsOneWidget);
    expect(find.text('a.txt'), findsOneWidget);

    await addFolder('/x');
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);
    expect(find.text('x'), findsOneWidget);

    // Text files for /x.
    await _openFilterMenu(tester);
    await tester.tap(_key('forge-explorer-preset:Text files'));
    await tester.pumpAndSettle();
    expect(find.text('c.png'), findsNothing);
    await store.flushed();
    expect(store.snapshot()['forge.view.explorer.roots'], {
      'roots': [
        {'name': 'x', 'uri': 'file:///x/'},
      ],
      'current': 'file:///x/',
    });

    // A new view over the same store: /x registered and shown, with its
    // filter.
    await _show(tester, make(), key: const ValueKey('again'));
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('c.png'), findsNothing);
    await tester.tap(_key('forge-explorer-root-menu'));
    await tester.pumpAndSettle();
    expect(_key('forge-explorer-root:/w'), findsOneWidget);
    expect(_key('forge-explorer-root:/x'), findsOneWidget);

    // Switch back to /w, then to /x again: each root keeps its filter.
    await tester.tap(_key('forge-explorer-root:/w'));
    await tester.pumpAndSettle();
    expect(find.text('a.txt'), findsOneWidget);
    await tester.tap(_key('forge-explorer-root-menu'));
    await tester.pumpAndSettle();
    await tester.tap(_key('forge-explorer-root:/x'));
    await tester.pumpAndSettle();
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('c.png'), findsNothing);

    // Removed: back to the host's root; nothing in the folder touched.
    await tester.tap(_key('forge-explorer-root-menu'));
    await tester.pumpAndSettle();
    await tester.tap(_key('forge-explorer-remove-root'));
    await tester.pumpAndSettle();
    expect(find.text('a.txt'), findsOneWidget);
    expect(await files.exists(Uri.file('/x/b.txt')), isTrue);
    await store.flushed();
    expect(store.snapshot()['forge.view.explorer.roots'], {
      'roots': <Object?>[],
      'current': 'file:///w/',
    });
  });

  testWidgets('the root switcher alone lists lazily, as Forge does', (
    tester,
  ) async {
    final files = _files({'/w/.env': '', '/w/lib/a.dart': ''});
    await _show(tester, _view(files, rootSwitcher: true));
    expect(_key('forge-explorer-header'), findsOneWidget);
    expect(_key('forge-explorer-filter-menu'), findsNothing);
    expect(_key('forge-explorer-footer'), findsNothing);
    expect(find.text('.env'), findsNothing);
    await _tapOpen(tester, 'lib');
    expect(find.text('a.dart'), findsOneWidget);
  });

  testWidgets('the walk stops at its limit and says so; a folder it did not '
      'finish is listed when opened', (tester) async {
    final files = _files({
      '/w/a/1.txt': '',
      '/w/a/2.txt': '',
      '/w/a/3.txt': '',
      '/w/b/4.txt': '',
      '/w/z.txt': '',
    });
    await _show(
      tester,
      _view(files, filter: const ForgeFilter([]), walkLimit: 3),
    );
    expect(_key('forge-explorer-walk-stopped'), findsOneWidget);
    expect(find.text('Stopped after 3 entries'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);

    await _tapOpen(tester, 'a');
    expect(find.text('1.txt'), findsOneWidget);
    expect(find.text('2.txt'), findsOneWidget);
    expect(find.text('3.txt'), findsOneWidget);

    // Without the limit nothing is said.
    await _show(
      tester,
      _view(files, filter: const ForgeFilter([])),
      key: const ValueKey('again'),
    );
    expect(_key('forge-explorer-walk-stopped'), findsNothing);
    expect(find.text('z.txt'), findsOneWidget);
  });

  test('the module hands its options to the view; the state store is the '
      'kit\'s only when configured', () {
    final store = ForgeMemoryStateStore();
    final api = DefaultKitApi(
      editorHost: _Host(),
      fileSystem: _files({}),
      stateStore: store,
    );
    addTearDown(api.dispose);
    final presets = ForgeBuiltInPresets.all;
    final plain = forgeFileExplorerModule(rootUri: Uri.directory('/w'));
    final filtering = forgeFileExplorerModule(
      rootUri: Uri.directory('/w'),
      filterPresets: presets,
      rootSwitcher: true,
      stateKey: 'second.explorer',
      walkLimit: 10,
    );
    api.registerModule(plain);
    plain.activate(api);
    filtering.activate(api);

    expect(plain.view!.filtering, isFalse);
    expect(plain.view!.rootSwitcher, isFalse);
    expect(plain.view!.stateStore, isNull);
    final view = filtering.view!;
    expect(view.filtering, isTrue);
    expect(view.filterPresets, same(presets));
    expect(view.rootSwitcher, isTrue);
    expect(view.stateStore, same(store));
    expect(view.stateKey, 'second.explorer');
    expect(view.walkLimit, 10);
  });
}

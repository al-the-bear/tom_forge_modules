// The Search view on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, searching the
// workspace's files and opening a match — at its position when the
// application is a ForgeFileNavigator, else through ForgeKitApi.openFile —
// and recording its query in a state that is a ForgeSearchQueryState.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_search_view/tom_forge_search_view.dart';

/// An editor host that is no layout: it records what it is asked to open.
class _Host implements ForgeEditorHost {
  final opened = <Uri>[];

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
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    opened.add(uri);
    return null;
  }
}

/// A kit state that records the query and knows the workspace folder, as
/// the panel shell's does.
class _State extends DefaultKitState
    implements ForgeSearchQueryState, ForgeWorkspaceRoot {
  final queries = <String>[];
  bool active = false;

  @override
  String get workspaceRootPath => '/w';

  @override
  void setSearchQuery(String query) => queries.add(query);

  @override
  void setSearchActive(bool active) => this.active = active;
}

/// A kit API that opens files at a position, as the panel shell's does.
class _NavigatingApi extends DefaultKitApi implements ForgeFileNavigator {
  _NavigatingApi({
    required super.editorHost,
    required super.fileSystem,
    super.state,
  });

  final positions = <(Uri, int?, int?)>[];

  @override
  void openFileAt(Uri uri, {int? line, int? column}) =>
      positions.add((uri, line, column));
}

final _uri = Uri.file('/w/lib/a.dart');

TomMemoryFileSystem _files() => TomMemoryFileSystem(
  seed: {
    _uri.toFilePath(): 'void main() {\n  greet();\n}\n',
    '/w/README.md': 'Nothing to find here.\n',
  },
);

Future<void> _search(WidgetTester tester, ForgeView view, String query) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: Builder(builder: view.buildMain),
        ),
      ),
    ),
  );
  expect(find.text('Type to search'), findsOneWidget);
  await tester.enterText(find.byType(TextField), query);
  // The view searches once typing pauses (300 ms), streaming file by file.
  await tester.pump(const Duration(milliseconds: 350));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the module contributes the view with its placement hint', () {
    final api = DefaultKitApi(editorHost: _Host(), fileSystem: _files());
    addTearDown(api.dispose);
    final module = forgeSearchViewModule();
    api.registerModule(module);

    final contributed = forgeContributedViews(api.modules);
    expect(contributed, hasLength(1));
    expect(contributed.single.view, isA<ForgeSearchView>());
    expect(contributed.single.hint, same(forgeSearchViewPlacement));
    expect(contributed.single.hint!.role, ForgeViewRole.navigation);
    expect(contributed.single.hint!.order, 10);
    expect(
      forgeContributedViewById(api.modules, forgeSearchViewId),
      same(module.view),
    );
    // A bare kit state is no ForgeSearchQueryState nor ForgeWorkspaceRoot.
    expect(module.view!.searchState, isNull);
    expect(module.view!.workspaceRoot, isNull);
  });

  testWidgets('finds the matches and opens one through the kit', (
    tester,
  ) async {
    final host = _Host();
    final api = DefaultKitApi(editorHost: host, fileSystem: _files());
    addTearDown(api.dispose);
    final module = forgeSearchViewModule(workspaceRoot: '/w');
    api.registerModule(module);

    await _search(tester, module.view!, 'greet');

    expect(find.text('1 matches in 1 files'), findsOneWidget);
    expect(find.text('a.dart'), findsOneWidget);
    expect(find.text('lib/a.dart'), findsOneWidget);
    await tester.tap(find.text('2: '));
    await tester.pumpAndSettle();
    expect(host.opened, [_uri]);
  });

  testWidgets('opens a match at its position and records the query in the '
      'application state', (tester) async {
    final host = _Host();
    final state = _State();
    final api = _NavigatingApi(
      editorHost: host,
      fileSystem: _files(),
      state: state,
    );
    addTearDown(api.dispose);
    final module = forgeSearchViewModule();
    api.registerModule(module);
    expect(module.view!.workspaceRoot, '/w');

    await _search(tester, module.view!, 'greet');

    expect(state.queries.last, 'greet');
    expect(state.active, isTrue);
    expect(find.text('lib/a.dart'), findsOneWidget);
    await tester.tap(find.text('2: '));
    await tester.pumpAndSettle();
    expect(api.positions, [(_uri, 1, 2)]);
    expect(host.opened, isEmpty);
  });
}

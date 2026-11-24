// The file explorer on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, listing the workspace's
// files, opening one through the kit (at its position when the application
// is a ForgeFileNavigator, else through ForgeKitApi.openFile), and sharing
// its selection with a state that is a ForgeExplorerSelection.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kDoubleTapTimeout, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

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

/// A kit state that knows the workspace folder and keeps the explorer's
/// selection, as the panel shell's does.
class _State extends DefaultKitState
    implements ForgeWorkspaceRoot, ForgeExplorerSelection {
  final _selected = ValueNotifier<List<Uri>>(const []);
  Uri? hovered;

  @override
  String get workspaceRootPath => '/w';

  @override
  List<Uri> get selectedExplorerItems => _selected.value;

  @override
  ValueListenable<List<Uri>> get selectedExplorerItemsListenable => _selected;

  @override
  void setSelectedExplorerItems(List<Uri> items) => _selected.value = items;

  @override
  void setHoveredExplorerItem(Uri? item) => hovered = item;
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

final _source = Uri.file('/w/lib/a.dart');
final _readme = Uri.file('/w/README.md');

TomMemoryFileSystem _files() => TomMemoryFileSystem(
  seed: {_source.toFilePath(): 'void main() {}\n', _readme.toFilePath(): '#\n'},
);

Future<void> _show(WidgetTester tester, ForgeView view) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: Builder(builder: view.buildMain),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('the module contributes the view with its placement hint', () {
    final api = DefaultKitApi(editorHost: _Host(), fileSystem: _files());
    addTearDown(api.dispose);
    final module = forgeFileExplorerModule(rootUri: Uri.directory('/w'));
    api.registerModule(module);

    final contributed = forgeContributedViews(api.modules);
    expect(contributed, hasLength(1));
    expect(contributed.single.view, isA<ForgeFileExplorerView>());
    expect(contributed.single.hint, same(forgeExplorerViewPlacement));
    expect(contributed.single.hint!.role, ForgeViewRole.navigation);
    expect(contributed.single.hint!.group, 'Explorer');
    expect(contributed.single.hint!.order, 0);
    expect(
      forgeContributedViewById(api.modules, forgeExplorerViewId),
      same(module.view),
    );
    expect(module.view!.rootUri, Uri.directory('/w'));
    expect(module.view!.contextMenus, same(api.contextMenus));
  });

  test('without a root it shows the state\'s workspace folder', () {
    final api = DefaultKitApi(
      editorHost: _Host(),
      fileSystem: _files(),
      state: _State(),
    );
    addTearDown(api.dispose);
    final module = forgeFileExplorerModule();
    api.registerModule(module);
    expect(module.view!.rootUri, Uri.directory('/w'));
  });

  testWidgets('lists the files and opens one through the kit', (tester) async {
    final host = _Host();
    final api = DefaultKitApi(editorHost: host, fileSystem: _files());
    addTearDown(api.dispose);
    final module = forgeFileExplorerModule(rootUri: Uri.directory('/w'));
    api.registerModule(module);
    final view = module.view!;
    expect(view.title.value, 'Explorer');

    await _show(tester, view);
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('a.dart'), findsNothing);

    // A tap expands a folder.
    await tester.tap(find.text('lib'));
    await tester.pumpAndSettle();
    expect(find.text('a.dart'), findsOneWidget);

    // A double tap opens a file.
    await _doubleTap(tester, find.text('a.dart'));
    expect(host.opened, [_source]);

    // So does Open in its context menu.
    await tester.tap(find.text('README.md'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(host.opened, [_source, _readme]);
  });

  testWidgets('opens through the application\'s file navigator and shares '
      'its selection', (tester) async {
    final host = _Host();
    final state = _State();
    final api = _NavigatingApi(
      editorHost: host,
      fileSystem: _files(),
      state: state,
    );
    addTearDown(api.dispose);
    final view = ForgeFileExplorerView(
      fileSystem: api.fileSystem,
      openFile: forgeOpenFileAtOf(api),
      rootUri: Uri.directory('/w'),
      selection: state,
    );

    await _show(tester, view);
    expect(find.text('a.dart'), findsNothing);

    // The application reveals a file: its folder opens, the row is selected.
    state.setSelectedExplorerItems([_source]);
    await tester.pumpAndSettle();
    expect(find.text('a.dart'), findsOneWidget);

    // A file's tap waits out the double-tap delay, then selects the row.
    await tester.tap(find.text('README.md'));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(state.selectedExplorerItems, [_readme]);

    await _doubleTap(tester, find.text('README.md'));
    expect(api.positions, [(_readme, null, null)]);
    expect(host.opened, isEmpty);
  });
}

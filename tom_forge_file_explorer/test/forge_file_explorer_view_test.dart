// The file explorer on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, listing the workspace's
// files, opening one through the kit (at its position when the application
// is a ForgeFileNavigator, else through ForgeKitApi.openFile), and sharing
// its selection with a state that is a ForgeExplorerSelection; a file with
// more than one editor has Open With ▸ in its context menu, built from the
// kit's editor picker.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show kDoubleTapTimeout, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show forgeContextMenuCheckKey, forgeContextMenuEntryKey;

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

/// A module offering two editors for Markdown files, recording what they
/// open.
class _MarkdownEditorsModule extends ForgeKitModule {
  final opened = <(String, Uri)>[];

  ForgeKitEditorChoice _choice(String id, String label) => ForgeKitEditorChoice(
    id: id,
    label: label,
    icon: Icons.description,
    open: (uri) => opened.add((id, uri)),
  );

  @override
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) => [
    if (uri.path.endsWith('.md')) ...[
      _choice('md', 'Markdown editor'),
      _choice('browser', 'MD Browser'),
    ],
  ];

  @override
  String get displayName => 'Markdown editors';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
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
  testWidgets('Open With ▸ for a file with more than one editor: open once, '
      'set the default, the checkmark moves and is kept', (tester) async {
    final store = ForgeMemoryStateStore();
    final files = _files();
    var editors = _MarkdownEditorsModule();
    DefaultKitApi makeApi() {
      final api = DefaultKitApi(
        editorHost: _Host(),
        fileSystem: files,
        stateStore: store,
      );
      api.registerModule(editors);
      api.registerModule(forgeFileExplorerModule(rootUri: Uri.directory('/w')));
      return api;
    }

    final api = makeApi();
    await api.restore();
    final view = forgeContributedViewById(api.modules, forgeExplorerViewId)!;
    expect(
      (view as ForgeFileExplorerView).editorPicker,
      same(api.editorPicker),
    );
    await _show(tester, view);

    Future<void> openMenu(String name) async {
      await tester.tap(find.text(name), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
    }

    final openWith = find.byKey(forgeContextMenuEntryKey(forgeOpenWithMenuId));
    final setDefault = find.byKey(
      forgeContextMenuEntryKey(forgeOpenWithSetDefaultMenuId),
    );

    // A file with one editor or none: no submenu.
    await tester.tap(find.text('lib'));
    await tester.pumpAndSettle();
    await openMenu('a.dart');
    expect(find.text('Open'), findsOneWidget);
    expect(openWith, findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // README.md: the editors; a click opens it once, the default unset.
    await openMenu('README.md');
    expect(openWith, findsOneWidget);
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(find.text('Markdown editor'), findsOneWidget);
    expect(find.text('MD Browser'), findsOneWidget);
    expect(find.text('Set default for .md'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.text('MD Browser'));
    await tester.pumpAndSettle();
    expect(editors.opened, [('browser', _readme)]);
    expect(api.getFileTypeDefaults(), isEmpty);

    // Set default for .md ▸ MD Browser: the default moves, nothing opens.
    await openMenu('README.md');
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        forgeContextMenuEntryKey(forgeOpenWithDefaultMenuId('browser')),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.getFileTypeDefaults(), {'.md': 'browser'});
    expect(editors.opened, hasLength(1));

    // The editors list marks the default; the inner submenu checks it.
    await openMenu('README.md');
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(find.text('MD Browser (default for .md)'), findsOneWidget);
    expect(
      find.byKey(
        forgeContextMenuCheckKey(forgeOpenWithChoiceMenuId('browser')),
      ),
      findsOneWidget,
    );
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        forgeContextMenuCheckKey(forgeOpenWithDefaultMenuId('browser')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(forgeContextMenuCheckKey(forgeOpenWithDefaultMenuId('md'))),
      findsNothing,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Kept: an application over the same store has the default.
    await api.flushed();
    api.dispose();
    editors = _MarkdownEditorsModule();
    final again = makeApi();
    await again.restore();
    expect(again.getFileTypeDefaults(), {'.md': 'browser'});
    expect(
      (await again.editorPicker.choicesFor(
        ForgeContentItem(_readme),
      )).defaultChoice?.id,
      'browser',
    );
    again.dispose();
  });
}

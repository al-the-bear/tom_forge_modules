// The Revisions view on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, listing the saved
// revisions of the active file, opening one through the kit and restoring
// one through the application's ForgeRevisionRestorer.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_revision_view/tom_forge_revision_view.dart';

class _Editor extends ForgeEditor {
  _Editor(this.uri);

  @override
  final Uri uri;

  @override
  ValueListenable<bool> get isDirty => ValueNotifier(false);

  @override
  void markClean() {}

  @override
  ValueListenable<String> get title => ValueNotifier(uri.pathSegments.last);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.note;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.accept;
}

/// An editor host that is no layout: it tells the kit state what is shown
/// and records what it was asked to open.
class _Host implements ForgeEditorHost {
  late DefaultKitState state;
  final List<Uri> opened = [];

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    state.addOpenEditor(editor);
    if (focus) state.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    state.removeOpenEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) => state.setActiveEditor(editor);

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    opened.add(uri);
    final editor = _Editor(uri);
    await showEditor(editor);
    return editor;
  }
}

class _Restorer implements ForgeRevisionRestorer {
  final List<(Uri, String)> restored = [];

  @override
  Future<bool> restoreFileFromRevision(Uri fileUri, String revisionId) async {
    restored.add((fileUri, revisionId));
    return true;
  }
}

void main() {
  final file = Uri.file('/w/notes.txt');
  late _Host host;
  late TomMemoryFileSystem fileSystem;
  late DefaultKitApi api;
  late ForgeRevisionViewModule module;

  setUp(() {
    host = _Host();
    fileSystem = TomMemoryFileSystem(seed: const {'/w/notes.txt': 'now\n'});
    api = DefaultKitApi(
      editorHost: host,
      fileSystem: fileSystem,
      stateStore: ForgeMemoryStateStore(),
    );
    host.state = api.state;
    module = forgeRevisionViewModule();
    api.registerModule(module);
  });

  tearDown(() => api.dispose());

  Widget hostOf(ForgeView view) => MaterialApp(
    home: Scaffold(body: Builder(builder: view.buildMain)),
  );

  test('the module contributes the view with its placement hint', () {
    final contributed = forgeContributedViews(api.modules);
    expect(contributed, hasLength(1));
    expect(contributed.single.view, isA<ForgeRevisionView>());
    expect(contributed.single.hint, same(forgeRevisionViewPlacement));
    expect(contributed.single.hint!.role, ForgeViewRole.navigation);
    expect(
      forgeContributedViewById(api.modules, forgeRevisionViewId),
      same(module.view),
    );
    // The kit's API restores nothing: the view offers no restore there.
    expect(module.view!.restorer, isNull);
  });

  testWidgets('lists the active file\'s revisions and opens one', (
    tester,
  ) async {
    final view = module.view!;
    late String revision;
    await tester.runAsync(() async {
      await api.workspaceState.initialize(fileSystem);
      revision = (await api.workspaceState.createRevision(file, 'before\n'))!;
    });

    await tester.pumpWidget(hostOf(view));
    await tester.pumpAndSettle();
    expect(find.text('No file selected'), findsOneWidget);

    await tester.runAsync(() => api.openFile(file));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final listed = find.byIcon(Icons.restore);
    expect(listed, findsOneWidget);

    await tester.tap(listed);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(host.opened, [file, Uri.parse('$file?revision=$revision')]);
  });

  testWidgets('restores a revision through the application\'s restorer', (
    tester,
  ) async {
    final restorer = _Restorer();
    final view = ForgeRevisionView(
      workspaceState: api.workspaceState,
      systemState: api.state,
      openFile: (uri) => api.openFile(uri),
      restorer: restorer,
    );
    late String revision;
    await tester.runAsync(() async {
      await api.workspaceState.initialize(fileSystem);
      revision = (await api.workspaceState.createRevision(file, 'before\n'))!;
      await api.openFile(file);
    });

    await tester.pumpWidget(hostOf(view));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.file_download));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(restorer.restored, [(file, revision)]);
  });
}

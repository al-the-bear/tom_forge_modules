// The Outline view on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, showing the symbol tree
// the outline provider gives for the active editor.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_outline_view/tom_forge_outline_view.dart';

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

/// An editor host that is no layout: it tells the kit state what is shown.
class _Host implements ForgeEditorHost {
  late DefaultKitState state;

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
    final editor = _Editor(uri);
    await showEditor(editor);
    return editor;
  }
}

const _range = ForgeTextRange.empty();

/// Gives one class with a method for every editor.
class _Provider implements ForgeOutlineProvider {
  final _changes = StreamController<void>.broadcast();

  @override
  bool canProvide(ForgeEditor editor) => true;

  @override
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor) async => [
    ForgeOutlineItem(
      label: 'Greeter',
      kind: ForgeSymbolKind.classKind,
      range: _range,
      selectionRange: _range,
      children: [
        ForgeOutlineItem(
          label: 'greet',
          kind: ForgeSymbolKind.method,
          detail: '()',
          range: _range,
          selectionRange: _range,
        ),
      ],
    ),
  ];

  @override
  Stream<void> get onDidChange => _changes.stream;
}

void main() {
  late _Host host;
  late DefaultKitApi api;
  late ForgeOutlineViewModule module;

  setUp(() {
    host = _Host();
    api = DefaultKitApi(
      editorHost: host,
      fileSystem: TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
    host.state = api.state;
    module = forgeOutlineViewModule();
    api.registerModule(module);
  });

  tearDown(() => api.dispose());

  test('the module contributes the view with its placement hint', () {
    final contributed = forgeContributedViews(api.modules);
    expect(contributed, hasLength(1));
    expect(contributed.single.view, isA<ForgeOutlineView>());
    expect(contributed.single.hint, same(forgeOutlineViewPlacement));
    expect(contributed.single.hint!.role, ForgeViewRole.details);
    expect(
      forgeContributedViewById(api.modules, forgeOutlineViewId),
      same(module.view),
    );
  });

  testWidgets('shows the outline of the active editor', (tester) async {
    final view = module.view!;
    api.outline.registerProvider(_Provider());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: view.buildMain)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No outline available'), findsOneWidget);
    expect(view.title.value, 'Outline');

    await api.openFile(Uri.file('/w/greeter.dart'));
    await tester.pumpAndSettle();

    expect(find.text('No outline available'), findsNothing);
    expect(find.text('Greeter'), findsOneWidget);
    expect(find.text('greet'), findsOneWidget);
    expect(find.text('()'), findsOneWidget);
  });
}

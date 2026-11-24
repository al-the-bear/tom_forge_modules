// The Output view on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, showing the lines of
// the application's output channels and clearing one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_output_view/tom_forge_output_view.dart';

/// An editor host that places nothing: the Output view opens no editor.
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

void main() {
  late DefaultKitApi api;
  late ForgeOutputViewModule module;

  setUp(() {
    api = DefaultKitApi(
      editorHost: _Host(),
      fileSystem: TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
    module = forgeOutputViewModule();
    api.registerModule(module);
  });

  tearDown(() => api.dispose());

  test('the module contributes the view with its placement hint', () {
    final contributed = forgeContributedViews(api.modules);
    expect(contributed, hasLength(1));
    expect(contributed.single.view, isA<ForgeOutputView>());
    expect(contributed.single.hint, same(forgeOutputViewPlacement));
    expect(contributed.single.hint!.role, ForgeViewRole.messages);
    expect(
      forgeContributedViewById(api.modules, forgeOutputViewId),
      same(module.view),
    );
  });

  testWidgets('shows a channel\'s lines as they come and clears them', (
    tester,
  ) async {
    final view = module.view!;
    Widget host() => MaterialApp(
      home: Scaffold(body: Builder(builder: view.buildMain)),
    );

    await tester.pumpWidget(host());
    expect(find.text('No output channels'), findsOneWidget);

    final channel = api.output.create('Build');
    channel.appendLine('compiling');
    // A new channel shows once the view is built again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Build'), findsOneWidget);
    expect(find.textContaining('compiling'), findsOneWidget);

    channel.appendLine('done');
    await tester.pumpAndSettle();
    expect(find.textContaining('done'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('compiling'), findsNothing);
    expect(find.textContaining('done'), findsNothing);
  });
}

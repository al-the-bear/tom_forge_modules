// The single-window example: a YAML file opened in the window's one editor,
// an edit undone with the window's Edit menu, a second edit saved with its
// toolbar into the kit's file system; the menus and the toolbar are the
// kit's models, the editor's place the example's own ForgeEditorHost.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_single_window_example/main.dart';

import 'support/kit_steps.dart';

void main() {
  KitYamlTool memoryTool(TomMemoryFileSystem fileSystem) => KitYamlTool.compose(
    fileSystem: fileSystem,
    stateStore: ForgeMemoryStateStore(),
  );

  testWidgets('KIT-1: a YAML file opens in the window; an edit is undone by '
      'Edit > Undo, a second one saved by the toolbar', (tester) async {
    await prepareSurface(tester);
    final fileSystem = TomMemoryFileSystem(
      seed: const {'/work/$sampleFileName': sampleFileContent},
    );
    final tool = memoryTool(fileSystem);
    await tester.pumpWidget(KitYamlApp(tool: tool));
    expect(find.text('No file open'), findsOneWidget);

    final file = Uri.file('/work/$sampleFileName');
    final editor = await openInWindow(tester, tool, file);
    expect(forgeEditorTypeIdOf(editor), 'yaml');
    expect(editor.kitApi, same(tool.api));

    await editUndoSave(tester, tool, editor);

    final saved = await fileSystem.readText(file);
    expect(saved, contains('version: 3'));
    expect(saved, contains('name: tom_forge_single_window_example'));
    expect(saved, isNot(contains('version: 1')));
  });

  testWidgets('KIT-2: the menus and the toolbar are the kit\'s models', (
    tester,
  ) async {
    final tool = memoryTool(
      TomMemoryFileSystem(seed: const {'/w/a.yaml': 'a: 1\n'}),
    );
    final api = tool.api;
    final file = ForgeMenuModel.of(api, ForgeMenuLocation.file);
    expect(file.title, 'File');
    expect(
      [
        for (final entry in file.entries)
          if (entry is ForgeMenuActionEntry) entry.action.id,
      ],
      [kitSaveActionId],
    );
    final edit = ForgeMenuModel.of(api, ForgeMenuLocation.edit);
    expect(
      [
        for (final entry in edit.entries)
          if (entry is ForgeMenuActionEntry) entry.action.id,
      ],
      [...kitHistoryActionIds, ...kitClipboardActionIds],
    );
    expect(edit.entries.whereType<ForgeMenuSeparatorEntry>(), hasLength(1));
    // Without an editor nothing can run.
    expect([
      for (final entry in edit.entries)
        if (entry is ForgeMenuActionEntry) entry.action.enabled,
    ], everyElement(isFalse));
    final toolbar = kitToolbarModel.resolve(api);
    expect(
      [for (final (section, _) in toolbar) section.id],
      ['kitExample.file', 'kitExample.history', 'kitExample.clipboard'],
    );
    expect(
      [for (final (_, actions) in toolbar) ...actions.map((a) => a.id)],
      [kitSaveActionId, ...kitHistoryActionIds, ...kitClipboardActionIds],
    );
    expect(api.shortcuts.getBinding(kitSaveActionId), isNotNull);
    expect(
      api.shortcuts.getBinding(StandardEditingActions.undoActionId),
      isNotNull,
    );
  });

  testWidgets('KIT-3: the host shows one editor at a time, keeps an unsaved '
      'one open and opens only what an editor type opens', (tester) async {
    await prepareSurface(tester);
    final tool = memoryTool(
      TomMemoryFileSystem(
        seed: const {
          '/w/a.yaml': 'a: 1\n',
          '/w/b.yml': 'b: 2\n',
          '/w/notes.txt': 'notes\n',
        },
      ),
    );
    await tester.pumpWidget(KitYamlApp(tool: tool));
    final a = await openInWindow(tester, tool, Uri.file('/w/a.yaml'));
    // The same file again: the same editor.
    expect(
      await tester.runAsync(() => tool.open(Uri.file('/w/a.yaml'))),
      same(a),
    );
    final b = await openInWindow(tester, tool, Uri.file('/w/b.yml'));
    expect(b, isNot(same(a)));
    expect(tool.api.state.openEditors, [b]);
    expect(
      await tester.runAsync(() => tool.open(Uri.file('/w/notes.txt'))),
      isNull,
    );
    expect(tool.editor, same(b));

    b.controller.setYaml('b: 3\n');
    await tester.pumpAndSettle();
    expect(b.isDirty.value, isTrue);
    expect(await tester.runAsync(() => tool.host.closeEditor(b)), isFalse);
    expect(tool.editor, same(b));
  });

  test('KIT-4: the command line names the file and the trails', () {
    final launch = KitLaunch.parse(['--trail=yaml', '/some/file.yaml']);
    expect(launch.file, '/some/file.yaml');
    expect(launch.trails, {'yaml'});
    expect(KitLaunch.parse(['--trail']).trails, {'all'});
    expect(KitLaunch.parse(['--file', '/a.yaml', '/b.yaml']).file, '/a.yaml');
    expect(KitLaunch.parse(const []).file, isNull);
  });
}

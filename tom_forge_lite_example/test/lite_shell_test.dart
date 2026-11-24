// The light panel shell example (forgerestruct16): a YAML file opened from
// the explorer opens in the YAML editor, an edit is undone through the
// shell's undo, and a second edit is saved through the shell's save into the
// shell's file system.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_lite_example/main.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

import 'support/lite_steps.dart';

void main() {
  testWidgets('LITE-1: the explorer opens a YAML file in the YAML editor; an '
      'edit is undone by the shell, a second one saved', (tester) async {
    await prepareSurface(tester);
    final fileSystem = TomMemoryFileSystem(
      seed: {
        for (final MapEntry(:key, :value) in sampleWorkspaceFiles.entries)
          '/workspace/$key': value,
      },
    );
    final lite = LiteForgeShell.compose(
      fileSystem: fileSystem,
      workspaceRoot: '/workspace',
      stateStore: ForgeMemoryStateStore(),
    );
    await tester.pumpWidget(LiteForgeApp(lite: lite));
    await tester.pumpAndSettle();

    // Only the explorer is contributed: it is the left panel's view.
    expect(lite.explorerModule.view, isNotNull);
    expect(lite.shell.modules.allKitModules, contains(lite.explorerModule));

    final config = Uri.file('/workspace/config.yaml');
    final editor = await openFromExplorer(tester, lite, config);
    expect(editor, isA<ForgeYamlEditor>());
    expect(forgeEditorTypeIdOf(editor), 'yaml');

    await editUndoSave(tester, lite, editor as ForgeYamlEditor);

    final saved = await fileSystem.readText(config);
    expect(saved, contains('version: 3'));
    expect(saved, contains('name: tom_forge_lite_example'));
    expect(editor.isDirty.value, isFalse);
  });

  test('LITE-2: the command line names the folder and the trails', () {
    final launch = LiteLaunch.parse(['--trail=yaml', '/some/folder']);
    expect(launch.workspace, '/some/folder');
    expect(launch.trails, {'yaml'});
    expect(LiteLaunch.parse(['--trail']).trails, {'all'});
    expect(LiteLaunch.parse(['--workspace', '/a', '/b']).workspace, '/a');
    expect(LiteLaunch.parse(const []).workspace, isNull);
  });
}

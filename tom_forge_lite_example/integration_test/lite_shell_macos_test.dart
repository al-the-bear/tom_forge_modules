// The light panel shell example built and started on macOS
// (forgerestruct16): `flutter test integration_test/lite_shell_macos_test.dart
// -d macos`. A YAML file of a workspace folder on disk is opened from the
// explorer, edited, the edit undone by the shell, a second edit saved, and
// the file read back from disk.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tom_file_system/io.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_lite_example/main.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

import '../test/support/lite_steps.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LITE-M1: on macOS a YAML file on disk is opened from the '
      'explorer, edited, undone, edited again and saved to disk', (
    tester,
  ) async {
    await prepareSurface(tester);
    // The workspace folder: the sample's files in the app's own temporary
    // folder, removed afterwards.
    final folder = Directory.systemTemp.createTempSync('lite_example_');
    addTearDown(() => folder.deleteSync(recursive: true));
    for (final MapEntry(:key, :value) in sampleWorkspaceFiles.entries) {
      final file = File('${folder.path}/$key');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(value);
    }
    final root = folder.resolveSymbolicLinksSync();

    final lite = LiteForgeShell.compose(
      fileSystem: TomLocalFileSystem(root),
      workspaceRoot: root,
      stateStore: ForgeMemoryStateStore(),
    );
    await tester.pumpWidget(LiteForgeApp(lite: lite));
    await tester.pumpAndSettle();

    final config = File('$root/config.yaml');
    final editor = await openFromExplorer(tester, lite, config.uri);
    expect(editor, isA<ForgeYamlEditor>());

    await editUndoSave(tester, lite, editor as ForgeYamlEditor);

    final saved = config.readAsStringSync();
    expect(saved, contains('version: 3'));
    expect(saved, contains('name: tom_forge_lite_example'));
  });
}

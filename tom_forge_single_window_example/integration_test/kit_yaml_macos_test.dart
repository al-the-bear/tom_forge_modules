// The single-window example built and started on macOS:
// `flutter test integration_test/kit_yaml_macos_test.dart -d macos`. A YAML
// file on disk is opened in the window, edited, the edit undone with the
// Edit menu, a second edit saved with the toolbar, and the file read back
// from disk.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tom_file_system/io.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_single_window_example/main.dart';

import '../test/support/kit_steps.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KIT-M1: on macOS a YAML file on disk is opened in the window, '
      'edited, undone, edited again and saved to disk', (tester) async {
    await prepareSurface(tester);
    // The file: the sample in the app's own temporary folder, removed
    // afterwards.
    final folder = Directory.systemTemp.createTempSync('kit_example_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final root = folder.resolveSymbolicLinksSync();
    final file = File('$root/$sampleFileName')
      ..writeAsStringSync(sampleFileContent);

    final tool = KitYamlTool.compose(
      fileSystem: TomLocalFileSystem(root),
      stateStore: ForgeMemoryStateStore(),
    );
    await tester.pumpWidget(KitYamlApp(tool: tool));
    await tester.pumpAndSettle();

    final editor = await openInWindow(tester, tool, file.uri);
    await editUndoSave(tester, tool, editor);

    final saved = file.readAsStringSync();
    expect(saved, contains('version: 3'));
    expect(saved, contains('name: tom_forge_single_window_example'));
  });
}

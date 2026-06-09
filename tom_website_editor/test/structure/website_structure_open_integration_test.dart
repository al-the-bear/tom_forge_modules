// Integration reproduction for "Opening file doesn't work in the structure
// explorer": drives a real shell (DefaultShellApi + MemoryFileSystem) through the
// full open seam — a tap on a structure-explorer file node must route through
// WebsiteEditorModule._openFile → ForgeLayoutController.openFile and end with the
// file's editor active in the shell. The widget-level seam is covered by
// website_structure_explorer_test.dart; this test pins the end-to-end path the
// module actually wires in the app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _contentConfig = '''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/site"
    content:
      dir: "{websiteRoot}/content"
''';

const _componentA = 'id: a\nname: A\ntagline: First\n';

void main() {
  testWidgets(
      'TWE-STRUCT-INT-01: tapping a structure-explorer file opens it in the shell',
      (tester) async {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/tom.website-editor.yaml': _contentConfig,
        '/site/content/components/a.yaml': _componentA,
      },
      appName: 'Test',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath('/');
    final module = WebsiteEditorModule();
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
    addTearDown(() {
      module.deactivate();
      shell.dispose();
    });

    // Let the config editor load + the structure tree do its first disk read.
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: module.structureView!.buildMain)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('a.yaml'), findsOneWidget,
        reason: 'structure tree should list the seeded component');

    await tester.tap(find.text('a.yaml'));
    await tester.pumpAndSettle();

    final active = shell.systemState.activeEditor;
    expect(active, isNotNull,
        reason: 'tapping a file node should open it in the shell');
    expect(active!.uri.path, '/site/content/components/a.yaml');
  });
}

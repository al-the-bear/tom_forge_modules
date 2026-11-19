/// The shell reaches the host's file dialogs and environment only through
/// its components (forgeinv9): Open File, Save As and File > Open Folder go
/// to the shell's [ForgeFilePickers]; without the desktop host nothing is
/// picked; Forge's desktop components carry the desktop host.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Pickers that answer fixed paths and record what was asked.
class _FakePickers extends ForgeFilePickers {
  final calls = <String>[];

  @override
  Future<String?> pickFolder({String? title, String? initialDirectory}) async {
    calls.add('folder:$title');
    return '/picked/folder';
  }

  @override
  Future<List<String>> pickFiles({
    String? title,
    bool allowMultiple = false,
    List<String>? extensions,
  }) async {
    calls.add('files:$title:$allowMultiple:${extensions?.join(',')}');
    return ['/picked/a.txt', if (allowMultiple) '/picked/b.txt'];
  }

  @override
  Future<String?> pickSaveLocation({
    String? title,
    String? suggestedName,
    List<FileFilter> filters = const [],
  }) async {
    calls.add('save:$title:$suggestedName:${filters.length}');
    return '/picked/out.md';
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(DefaultShellApi, List<String>)> pump(
    WidgetTester tester, {
    ForgeShellComponents? components,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final opened = <String>[];
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'host ports',
      navigatorKey: GlobalKey<NavigatorState>(),
      components: components,
    );
    final module = TomForgeShellModule();
    (shell.modules as DefaultModuleRegistry).register(module);
    module.activate(shell);
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeShellScaffold(
          shell: shell,
          layoutController: shell.layout as DefaultLayoutController,
          systemState: shell.systemState as DefaultSystemState,
          statusBarController: shell.statusBar,
          notificationManager:
              shell.notifications as DefaultNotificationManager,
          onOpenFolder: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (shell, opened);
  }

  testWidgets('HP-1: Open File, Save As and Open Folder go through the '
      "shell's file pickers", (tester) async {
    final pickers = _FakePickers();
    final (shell, opened) = await pump(
      tester,
      components: ForgeShellComponents(filePickers: pickers),
    );

    final one = await shell.dialogs.showOpenDialog(
      title: 'Open',
      filters: [
        FileFilter(name: 'Text', extensions: ['txt']),
      ],
    );
    expect(one, [Uri.file('/picked/a.txt')]);
    final many = await shell.dialogs.showOpenDialog(canSelectMany: true);
    expect(many, [Uri.file('/picked/a.txt'), Uri.file('/picked/b.txt')]);
    final saved = await shell.dialogs.showSaveDialog(
      title: 'Save As',
      defaultUri: Uri.file('/w/notes.md'),
    );
    expect(saved, Uri.file('/picked/out.md'));

    shell.executeAction('file.openFolder');
    await tester.pumpAndSettle();
    expect(opened, ['/picked/folder']);

    expect(pickers.calls, [
      'files:Open:false:txt',
      'files:Open File:true:null',
      'save:Save As:notes.md:0',
      'folder:Open Workspace Folder',
    ]);
  });

  testWidgets('HP-2: without the desktop host nothing is picked', (
    tester,
  ) async {
    final (shell, opened) = await pump(
      tester,
      components: const ForgeShellComponents(),
    );
    expect(await shell.dialogs.showOpenDialog(), isNull);
    expect(await shell.dialogs.showSaveDialog(), isNull);
    shell.executeAction('file.openFolder');
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(shell.components.pickers.available, isFalse);
    expect(shell.components.host.installedShells(), isEmpty);
    expect(
      () => shell.components.host.ensureFolder('/x'),
      throwsUnsupportedError,
    );
  });

  test("HP-3: Forge's desktop components carry the desktop host", () {
    expect(forgeDesktopComponents.filePickers, isA<DesktopFilePickers>());
    expect(
      forgeDesktopComponents.hostEnvironment,
      isA<DesktopHostEnvironment>(),
    );
    // And the other parts are still there.
    expect(forgeDesktopComponents.terminalManager, isNotNull);
    expect(forgeDesktopComponents.secretStorage, isNotNull);
    expect(forgeDesktopComponents.editorTypes.map((t) => t.id), [
      'md',
      'dart',
      'yaml',
    ]);
  });
}

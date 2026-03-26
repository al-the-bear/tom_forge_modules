import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  testWidgets('shell scaffold applies persisted text settings on startup', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'forge.editor.textSettings': jsonEncode({
        'md': {
          'fontFamily': 'Fira Code',
          'fontSize': 17.0,
          'lineHeight': 1.5,
          'tabSize': 3,
          'insertSpaces': true,
          'showWhitespace': true,
          'wordWrap': false,
          'showLineNumbers': true,
          'highlightCurrentLine': true,
          'maxUndoHistory': 120,
        },
      }),
    });

    final preferences = ForgePreferencesService();
    await preferences.load();

    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Phase C Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(shellModule);

    final application = ForgeApplication(
      title: 'Phase C Harness',
      layout: ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeShellScaffold(
          shell: shell,
          application: application,
          layoutController: shell.layout as DefaultLayoutController,
          systemState: shell.systemState as DefaultSystemState,
          statusBarController: shell.statusBar,
          notificationManager: shell.notifications as DefaultNotificationManager,
          preferencesService: preferences,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      shell.getTextSettings('md'),
      equals(
        const ForgeTextSettings(
          fontFamily: 'Fira Code',
          fontSize: 17,
          lineHeight: 1.5,
          tabSize: 3,
          insertSpaces: true,
          showWhitespace: true,
          wordWrap: false,
          showLineNumbers: true,
          highlightCurrentLine: true,
          maxUndoHistory: 120,
        ),
      ),
    );
  });
}

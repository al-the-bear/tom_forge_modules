import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
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
      layout: PanelLayout(
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
          notificationManager:
              shell.notifications as DefaultNotificationManager,
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

  testWidgets(
    'shell scaffold syncs updated preference text settings at runtime',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final preferences = ForgePreferencesService();
      await preferences.load();

      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Phase C Runtime Sync Harness',
        navigatorKey: navigatorKey,
      );

      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);

      final application = ForgeApplication(
        title: 'Phase C Runtime Sync Harness',
        layout: const PanelLayout(
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
            notificationManager:
                shell.notifications as DefaultNotificationManager,
            preferencesService: preferences,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const updated = ForgeTextSettings(
        fontFamily: 'JetBrains Mono',
        fontSize: 15,
        lineHeight: 1.45,
        tabSize: 2,
        insertSpaces: true,
        showWhitespace: false,
        wordWrap: true,
        showLineNumbers: true,
        highlightCurrentLine: true,
        maxUndoHistory: 180,
      );

      preferences.setEditorTextSettings('md', updated);
      await tester.pumpAndSettle();

      expect(shell.getTextSettings('md'), equals(updated));
    },
  );

  testWidgets('layout panel size and split state persist across restart', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final preferences = ForgePreferencesService();
    await preferences.load();

    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/workspace/sample.md': 'sample'},
      appName: 'Phase C Layout Harness',
      navigatorKey: navigatorKey,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(shellModule);

    final application = ForgeApplication(
      title: 'Phase C Layout Harness',
      layout: const PanelLayout(
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
          notificationManager:
              shell.notifications as DefaultNotificationManager,
          preferencesService: preferences,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstLayout = shell.layout as DefaultLayoutController;
    firstLayout.setPanelSize(ForgePanelLocation.left, 333);
    firstLayout.splitMiddlePanel();

    await tester.pump(const Duration(milliseconds: 700));

    // Simulate app restart by disposing scaffold and creating fresh shell.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final restoredPreferences = ForgePreferencesService();
    await restoredPreferences.load();

    final restoredShell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/workspace/sample.md': 'sample'},
      appName: 'Phase C Layout Harness (Restored)',
      navigatorKey: GlobalKey<NavigatorState>(),
    );

    final restoredModule = TomForgeShellModule();
    restoredModule.activate(restoredShell);
    (restoredShell.modules as DefaultModuleRegistry).register(restoredModule);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeShellScaffold(
          shell: restoredShell,
          application: application,
          layoutController: restoredShell.layout as DefaultLayoutController,
          systemState: restoredShell.systemState as DefaultSystemState,
          statusBarController: restoredShell.statusBar,
          notificationManager:
              restoredShell.notifications as DefaultNotificationManager,
          preferencesService: restoredPreferences,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final restoredLayout = restoredShell.layout as DefaultLayoutController;
    expect(restoredLayout.leftPanel.value.size, closeTo(333, 0.001));
    expect(restoredLayout.middlePanels.value.length, 2);
  });
}

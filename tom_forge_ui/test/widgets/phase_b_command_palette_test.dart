import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  testWidgets('command palette lists actions from action registry', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Palette Test',
      navigatorKey: navigatorKey,
    );

    final action = ForgeAction(
      id: 'file.save',
      label: 'Registry Save',
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
      defaultShortcut: ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
      ),
    );

    shell.actionRegistry.registerAction(action);
    (shell.shortcuts as DefaultShortcutManager).loadBindings([
      ForgeShortcutBinding(
        action: action,
        key: const ForgeShortcutKey(
          key: LogicalKeyboardKey.keyS,
          primaryModifier: true,
        ),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeCommandPalette(
            shellApi: shell,
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registry Save'), findsOneWidget);

    final usesMeta = defaultTargetPlatform == TargetPlatform.macOS;
    expect(find.text(usesMeta ? '⌘+S' : 'Ctrl+S'), findsOneWidget);
  });
}

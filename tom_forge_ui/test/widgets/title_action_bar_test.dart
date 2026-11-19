/// The title bar's action bar is the shared ForgeActionBar (02b_woneb2):
/// the shell maps its default action ids onto items, with the registry's
/// labels, the shortcut text and the enablement the editors give.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('TAB-1: the default actions are buttons of the shared action '
      'bar, labelled from the registry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'title action bar',
      navigatorKey: GlobalKey<NavigatorState>(),
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<ForgeActionBar>(find.byType(ForgeActionBar));
    final ids = [
      for (final g in bar.groups)
        for (final i in g.items) i.id,
    ];
    final expected = [
      for (final id in [
        'forge.edit.cut',
        'forge.edit.copy',
        'forge.edit.paste',
        'forge.edit.undo',
        'forge.edit.redo',
      ])
        if (shell.actionRegistry.getAction(id) != null) id,
    ];
    expect(
      expected,
      isNotEmpty,
      reason: 'the shell registers its edit actions',
    );
    expect(ids, expected);
    for (final item in [for (final g in bar.groups) ...g.items]) {
      final action = shell.actionRegistry.getAction(item.id)!;
      expect(item.label, action.label);
      expect(item.shortcut, shell.shortcuts.getBinding(item.id)?.displayString);
      expect(
        find.byKey(ValueKey('forge.actionBar.${item.id}')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey('forge.actionBar.overflow')),
      findsNothing,
      reason: 'the title bar gives the bar the room it needs',
    );
  });
}

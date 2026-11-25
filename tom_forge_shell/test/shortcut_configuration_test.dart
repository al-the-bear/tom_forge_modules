// The shell's key bindings are a configuration description
// (ForgeShortcutConfiguration): two key binding tables over the shell's
// actions, kept under the keys and in the encodings ForgePreferencesService
// always wrote, and changing them still changes the live shortcuts as the
// hand-written sections did.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';

typedef _S = ForgeShortcutConfiguration;

class _View extends ForgeView {
  @override
  ValueListenable<String> get title => ValueNotifier('Files');
  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);
  @override
  IconData get icon => Icons.folder;
  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();
  @override
  Widget buildMain(BuildContext context) => const Text('files body');
  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

Future<DefaultShellApi> _openShell(
  WidgetTester tester,
  ForgeMemoryStateStore store,
) async {
  await tester.binding.setSurfaceSize(const Size(1600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: const {},
    appName: 'Shortcut configuration',
    navigatorKey: GlobalKey<NavigatorState>(),
    stateStore: store,
  );
  shell.registerModule(TomForgeShellModule());
  shell.applications.add(
    ForgeApplication(
      id: 'shortcutConfiguration',
      title: 'Shortcut configuration',
      layout: PanelLayout(
        leftPanel: PanelConfig(
          tabs: [
            PanelTabConfig(
              title: 'Files',
              icon: Icons.folder,
              sections: [_View()],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ForgeShellScaffold(
        shell: shell,
        layoutController: shell.layout as DefaultLayoutController,
        systemState: shell.systemState as DefaultSystemState,
        statusBarController: shell.statusBar,
        notificationManager: shell.notifications as DefaultNotificationManager,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(shell.executeAction('forge.openSettings'), isTrue);
  await tester.pumpAndSettle();
  return shell;
}

ForgeConfigurationValues _valuesOf(WidgetTester tester) => tester
    .widget<ForgeConfigurationScope>(find.byType(ForgeConfigurationScope).first)
    .values;

Future<void> _settle(WidgetTester tester, ForgeMemoryStateStore store) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(store.flushed);
  await tester.pumpAndSettle();
}

const _f9 = ForgeShortcutKey(key: LogicalKeyboardKey.f9, shift: true);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('the description is valid: unique ids, known kinds', () {
    expect(_S.description.problems(), isEmpty);
  });

  testWidgets('the shell contributes the two key binding sections, and quick '
      'open\'s indices 5 and 6 open them', (tester) async {
    final store = ForgeMemoryStateStore();
    final shell = await _openShell(tester, store);
    expect(find.text('Shortcuts'), findsWidgets);
    expect(find.text('Chord Shortcuts'), findsWidgets);

    // The catalogue lists the shell's actions with their bindings.
    final actions = _S.catalogueActions(shell);
    final bound = shell.shortcuts.allBindings.firstWhere((b) => !b.isChord);
    final entry = actions.firstWhere((a) => a.id == bound.action.id);
    expect(entry.defaultBinding, ForgeKeyChord([_S.strokeOf(bound.key)]));

    final target = ValueNotifier<int?>(null);
    addTearDown(target.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 1600,
            child: ForgeConfigurationPanel(
              preferencesService: ForgePreferencesService.forStore(store),
              shellApi: shell,
              expandSection: target,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    target.value = 5;
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('forge.configuration.tile.forge.shortcuts/shortcuts'),
      ),
      findsOneWidget,
    );
    target.value = 6;
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('forge.configuration.tile.forge.shortcuts/chords'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('a rebind, a reset, a delete and an undelete change the '
      'preferences and the live shortcuts', (tester) async {
    final store = ForgeMemoryStateStore();
    final shell = await _openShell(tester, store);
    final prefs = ForgePreferencesService.forStore(store);
    final values = _valuesOf(tester);
    final binding = shell.shortcuts.allBindings.firstWhere((b) => !b.isChord);
    final id = binding.action.id;
    final defaultKey = binding.key;

    // Rebind: stored as the shell always stored it, bound live.
    expect(
      await values.set(
        _S.shortcuts,
        ForgeKeyBindingTable({
          id: ForgeKeyChord([_S.strokeOf(_f9)]),
        }),
      ),
      isNull,
    );
    await _settle(tester, store);
    expect(prefs.shortcutOverrides[id], _f9);
    expect(shell.shortcuts.getBinding(id)?.key, _f9);
    final stored = jsonDecode(
      store.snapshot()['forge.shortcuts.overrides']! as String,
    );
    expect((stored as Map)[id]['keyId'], LogicalKeyboardKey.f9.keyId);

    // Reset: the override goes, the default key is back.
    await values.reset(_S.shortcuts);
    await _settle(tester, store);
    expect(prefs.shortcutOverrides.containsKey(id), isFalse);
    expect(shell.shortcuts.getBinding(id)?.key, defaultKey);

    // Delete: the binding goes, the action is remembered as deleted.
    expect(await values.set(_S.deletedBindings, [id]), isNull);
    await _settle(tester, store);
    expect(prefs.deletedBindings, contains(id));
    expect(shell.shortcuts.getBinding(id), isNull);

    // Undelete: the default key is back.
    expect(await values.set(_S.deletedBindings, <String>[]), isNull);
    await _settle(tester, store);
    expect(prefs.deletedBindings, isNot(contains(id)));
    expect(shell.shortcuts.getBinding(id)?.key, defaultKey);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('stored overrides of an existing user are read unchanged', (
    tester,
  ) async {
    final store = ForgeMemoryStateStore(
      initial: {
        'forge.shortcuts.overrides': jsonEncode({
          'forge.openSettings': {
            'keyId': LogicalKeyboardKey.f9.keyId,
            'primaryModifier': false,
            'control': false,
            'shift': true,
            'alt': false,
          },
        }),
      },
    );
    await _openShell(tester, store);
    final table = _valuesOf(tester).valueOf(_S.shortcuts);
    expect(
      table.overrides['forge.openSettings'],
      ForgeKeyChord([_S.strokeOf(_f9)]),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}

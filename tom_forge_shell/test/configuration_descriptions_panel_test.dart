// The configuration side panel draws the configuration descriptions the kit
// modules contribute: one accordion entry per described section, after the
// shell's own Shell and Terminal sections and before the built-in sections,
// its body a tile over the shell's state store.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';

const _wrapSetting = ForgeBoolSetting(
  id: 'wrap',
  storage: ForgeSettingStorage('described.wrap'),
  label: ForgeText('described.wrap', 'Wrap long lines'),
);

const _sizeSetting = ForgeIntSetting(
  id: 'size',
  storage: ForgeSettingStorage('described.size'),
  label: ForgeText('described.size', 'Tab size'),
  defaultValue: 4,
  min: 1,
  max: 16,
);

const _description = ForgeConfigurationDescription(
  id: 'described',
  title: ForgeText('described', 'Described module'),
  sections: [
    ForgeSettingsSection(
      id: 'editing',
      title: ForgeText('described.editing', 'Described editing'),
      settings: [_wrapSetting, _sizeSetting],
    ),
  ],
);

/// A kit module that describes its options.
class _DescribedModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  @override
  String get displayName => 'Described';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => const [
    ForgeConfigurationDescriptionsExtra([_description]),
  ];
}

/// The view of the left panel the configuration panel opens in.
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

Finder _entry(ForgeSetting<Object> setting) => find.byKey(
  ValueKey('forge.configuration.setting.${setting.storage.location}'),
);

Future<DefaultShellApi> _openSettings(
  WidgetTester tester,
  ForgeMemoryStateStore store, {
  bool described = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: const {},
    appName: 'Described configuration',
    navigatorKey: GlobalKey<NavigatorState>(),
    stateStore: store,
  );
  shell.registerModule(TomForgeShellModule());
  if (described) shell.registerModule(_DescribedModule());
  shell.applications.add(
    ForgeApplication(
      id: 'described',
      title: 'Described',
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a described section is an entry after the shell\'s own and '
      'before the built-in ones, and its edits go to the shell\'s state '
      'store', (tester) async {
    final store = ForgeMemoryStateStore();
    await _openSettings(tester, store);

    final header = find.text('Described editing');
    expect(header, findsOneWidget);
    // After the shell's Terminal section, before the first built-in section.
    expect(
      tester.getTopLeft(header).dy,
      greaterThan(tester.getTopLeft(find.text('Terminal').first).dy),
    );
    expect(
      tester.getTopLeft(header).dy,
      lessThan(tester.getTopLeft(find.text('Shortcuts').first).dy),
    );
    // Collapsed at first: the Shell section stays the one expanded.
    expect(find.byType(ForgeConfigurationTile), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forge.configuration.tile.described/editing')),
      findsNothing,
    );

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forge.configuration.tile.described/editing')),
      findsOneWidget,
    );
    expect(find.text('Wrap long lines'), findsOneWidget);
    expect(find.text('Tab size'), findsOneWidget);

    await tester.tap(
      find.descendant(of: _entry(_wrapSetting), matching: find.byType(Switch)),
    );
    await tester.enterText(
      find.descendant(
        of: _entry(_sizeSetting),
        matching: find.byType(TextField),
      ),
      '8',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(store.flushed);
    expect(store.snapshot()['described.wrap'], true);
    expect(store.snapshot()['described.size'], 8);

    // A new values service over the same store reads them back.
    final again = ForgeConfigurationValues(store, descriptions: [_description]);
    await tester.runAsync(again.load);
    expect(again.valueOf(_wrapSetting), isTrue);
    expect(again.valueOf(_sizeSetting), 8);
    again.dispose();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('without module descriptions the panel shows the shell\'s own '
      'sections and the built-in ones', (tester) async {
    await _openSettings(tester, ForgeMemoryStateStore(), described: false);
    expect(find.text('Described editing'), findsNothing);
    // The Shell section's tile, open at first.
    expect(find.byType(ForgeConfigurationTile), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forge.configuration.tile.forge.shell/shell')),
      findsOneWidget,
    );
    expect(find.text('Shell'), findsWidgets);
    expect(find.text('Terminal'), findsWidgets);
    expect(find.text('Shortcuts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

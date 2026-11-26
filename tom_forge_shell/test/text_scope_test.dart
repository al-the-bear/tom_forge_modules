// A module's texts in the panel shell are read under the scope the module
// was constructed in (the workspace guideline i18n.md): its configuration
// description in the side panel and its action in the Tools menu, for two
// modules mounted under two scopes with the same ids.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

ForgeConfigurationDescription _description(String id) =>
    ForgeConfigurationDescription(
      id: id,
      title: const ForgeText.id('editing.editingSection.title'),
      sections: [
        ForgeSettingsSection(
          id: 'editing',
          title: const ForgeText.id('editing.editingSection.title'),
          order: 200,
          settings: [
            ForgeBoolSetting(
              id: 'wrap',
              storage: ForgeSettingStorage('$id.wrap'),
              label: const ForgeText.id('editing.wrapSwitch.label'),
            ),
          ],
        ),
      ],
    );

/// A module with a described section and a Tools action, both worded by ids
/// of its package.
class _Module extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _Module(this.name);

  final String name;

  @override
  String get displayName => name;
  @override
  void activate(ForgeKitApi api) {}
  @override
  void deactivate() {}
  @override
  List<ForgeEditor> get editors => const [];
  @override
  List<ForgeView> get views => const [];
  @override
  List<ForgeAction> get actions => [
    ForgeAction(
      id: '$name.run',
      title: const ForgeText.id('actions.runAction.label'),
      menu: ForgeMenuLocation.tools,
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    ),
  ];
  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
  @override
  List<ForgeModuleExtra> get ownExtras => [
    ForgeConfigurationDescriptionsExtra([_description(name)]),
  ];
}

class _OtherModule extends _Module {
  _OtherModule(super.name);
}

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

Map<String, dynamic> _texts(String side) => {
  'editing': {
    'editingSection': {'title': '$side editing'},
    'wrapSwitch': {'label': 'Wrap on the $side'},
  },
  'actions': {
    'runAction': {'label': 'Run on the $side'},
  },
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    installTexts({'left': _texts('left'), 'right': _texts('right')});
  });
  tearDown(clearTexts);

  testWidgets('two modules mounted under two scopes: their sections and '
      'their Tools actions in two wordings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Scoped texts',
      navigatorKey: GlobalKey<NavigatorState>(),
      stateStore: ForgeMemoryStateStore(),
    );
    shell.registerModule(TomForgeShellModule());
    shell.registerModule(runInScopePath('left', () => _Module('left')));
    shell.registerModule(runInScopePath('right', () => _OtherModule('right')));
    shell.applications.add(
      ForgeApplication(
        id: 'scoped',
        title: 'Scoped',
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
          notificationManager:
              shell.notifications as DefaultNotificationManager,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Tools menu.
    await tester.tap(find.text('Tools').first);
    await tester.pumpAndSettle();
    expect(find.text('Run on the left'), findsOneWidget);
    expect(find.text('Run on the right'), findsOneWidget);
    await tester.tapAt(const Offset(800, 1000));
    await tester.pumpAndSettle();

    // The configuration side panel: section headers and, opened, the tiles.
    expect(shell.executeAction('forge.openSettings'), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('left editing'), findsOneWidget);
    expect(find.text('right editing'), findsOneWidget);
    await tester.tap(find.text('left editing'));
    await tester.pumpAndSettle();
    expect(find.text('Wrap on the left'), findsOneWidget);
    await tester.tap(find.text('right editing'));
    await tester.pumpAndSettle();
    expect(find.text('Wrap on the right'), findsOneWidget);
    expect(find.textContaining('editing.wrapSwitch'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}

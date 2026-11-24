// The panel shell names no view: its panels are laid out from the views the
// registered modules contribute, each placed by its layout-free hint
// (forgeContributedPanelTabs), and a shell with no views starts. (The
// scaffold disposes the shell when it is torn down.)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation;
import 'package:tom_forge_shell/tom_forge_shell.dart';

/// A view showing its title.
class _View extends ForgeView {
  _View(this.name, this.iconData);

  final String name;
  final IconData iconData;

  @override
  ValueListenable<String> get title => ValueNotifier(name);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => iconData;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text('$name body');

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// A module written against the kit alone that contributes views with
/// placement hints (and one without).
class _ViewsModule extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _ViewsModule(
    this.displayName,
    this.contributions, {
    this.unplaced = const [],
  });

  final List<ForgeViewContribution> contributions;
  final List<ForgeView> unplaced;

  @override
  final String displayName;

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => [
    for (final c in contributions) c.view,
    ...unplaced,
  ];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => [
    ForgeViewContributionsExtra(contributions),
  ];
}

/// A second module type: the registry keeps one module per type.
class _MoreViewsModule extends _ViewsModule {
  _MoreViewsModule(super.displayName, super.contributions);
}

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'Contributed views',
  navigatorKey: GlobalKey<NavigatorState>(),
);

Widget _scaffold(DefaultShellApi shell) => MaterialApp(
  home: ForgeShellScaffold(
    shell: shell,
    layoutController: shell.layout as DefaultLayoutController,
    systemState: shell.systemState as DefaultSystemState,
    statusBarController: shell.statusBar,
    notificationManager: shell.notifications as DefaultNotificationManager,
  ),
);

Future<void> _largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a panel shell with no views starts', (tester) async {
    await _largeSurface(tester);
    final shell = _shell();
    shell.registerModule(TomForgeShellModule());

    expect(forgeContributedViews(shell.modules), isEmpty);
    final layout = forgeContributedPanelLayout(shell.modules);
    expect(layout.leftPanel.tabs, isEmpty);
    expect(layout.rightPanel.tabs, isEmpty);
    expect(layout.bottomPanel.tabs, isEmpty);
    shell.applications.add(
      ForgeApplication(id: 'empty', title: 'Empty', layout: layout),
    );

    await tester.pumpWidget(_scaffold(shell));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ForgeShellScaffold), findsOneWidget);
    expect(shell.applications.active?.id, 'empty');
  });

  testWidgets('the panels are laid out from the contributed views by their '
      'hints', (tester) async {
    await _largeSurface(tester);
    final shell = _shell();
    shell.registerModule(TomForgeShellModule());

    final files = _View('Files', Icons.folder);
    final history = _View('History', Icons.history);
    final find_ = _View('Find', Icons.search);
    final symbols = _View('Symbols', Icons.account_tree);
    final log = _View('Log', Icons.terminal);
    final hidden = _View('Hidden', Icons.block);
    shell.registerModule(
      _ViewsModule(
        'Views',
        [
          // Out of order on purpose: the hints order them.
          ForgeViewContribution(
            view: find_,
            hint: const ForgeViewPlacementHint(
              id: 'test.find',
              role: ForgeViewRole.navigation,
              order: 10,
            ),
          ),
          ForgeViewContribution(
            view: files,
            hint: const ForgeViewPlacementHint(
              id: 'test.files',
              role: ForgeViewRole.navigation,
              group: 'Explorer',
              groupIcon: Icons.folder_outlined,
            ),
          ),
          ForgeViewContribution(
            view: symbols,
            hint: const ForgeViewPlacementHint(
              id: 'test.symbols',
              role: ForgeViewRole.details,
            ),
          ),
          ForgeViewContribution(
            view: log,
            hint: const ForgeViewPlacementHint(
              id: 'test.log',
              role: ForgeViewRole.messages,
            ),
          ),
        ],
        unplaced: [hidden],
      ),
    );
    // A second module joins a group of the first.
    shell.registerModule(
      _MoreViewsModule('History', [
        ForgeViewContribution(
          view: history,
          hint: const ForgeViewPlacementHint(
            id: 'test.history',
            role: ForgeViewRole.navigation,
            group: 'Explorer',
            order: 1,
          ),
        ),
      ]),
    );

    expect(forgeContributedViewById(shell.modules, 'test.history'), history);
    expect(forgeContributedViewById(shell.modules, 'test.unknown'), isNull);

    final left = forgeContributedPanelTabs(
      shell.modules,
      ForgePanelLocation.left,
    );
    expect(left.map((t) => t.title), ['Explorer', 'Find']);
    expect(left.first.icon, Icons.folder_outlined);
    expect(left.first.sections, [files, history]);
    expect(left.last.icon, Icons.search);
    expect(left.last.sections, [find_]);
    final right = forgeContributedPanelTabs(
      shell.modules,
      ForgePanelLocation.right,
    );
    expect(right.map((t) => t.title), ['Symbols']);
    final bottom = forgeContributedPanelTabs(
      shell.modules,
      ForgePanelLocation.bottom,
    );
    expect(bottom.map((t) => t.title), ['Log']);
    expect(
      forgeContributedViews(
        shell.modules,
      ).where((c) => c.hint == null).single.view,
      hidden,
    );

    shell.applications.add(
      ForgeApplication(
        id: 'contributed',
        title: 'Contributed',
        layout: forgeContributedPanelLayout(shell.modules),
      ),
    );
    await tester.pumpWidget(_scaffold(shell));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Files body'), findsOneWidget);
    expect(find.text('Symbols body'), findsOneWidget);
    expect(find.text('Log body'), findsOneWidget);
    expect(find.text('Hidden body'), findsNothing);
  });
}

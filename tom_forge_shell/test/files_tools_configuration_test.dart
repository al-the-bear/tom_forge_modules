// File types and external tools are configuration descriptions
// (ForgeFileTypesConfiguration, ForgeExternalToolsConfiguration): kept under
// the keys and in the encodings ForgePreferencesService always wrote, and
// changing them still changes the shell's file type defaults and the tools'
// paths as the hand-written sections did.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';

typedef _F = ForgeFileTypesConfiguration;
typedef _T = ForgeExternalToolsConfiguration;

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

/// A tool whose check answers a fixed copy; its help names the copy.
class _Tool extends ForgeExternalTool {
  ForgeToolCopy copy = const ForgeToolCopy.missing(reason: 'not found');

  @override
  String get id => 'fake';

  @override
  String get name => 'Fake Tool';

  @override
  String get pathHint => 'Fake.app';

  @override
  String? get downloadUrl => 'https://example.org/fake';

  @override
  Future<ForgeToolCopy> check(String? path) async => copy;

  @override
  Future<List<ForgeToolCopy>> autoDetect() async => [
    const ForgeToolCopy(
      path: '/Applications/Fake.app',
      state: ForgeToolState.found,
      version: '2.0',
    ),
  ];

  @override
  Widget? buildHelp(
    BuildContext context,
    ForgeToolCopy copy, {
    required Future<void> Function() checkAgain,
  }) => Text('help for ${copy.state.name}');
}

/// A tool with no help of its own: its row shows where to get it.
class _PlainTool extends _Tool {
  @override
  String get id => 'plain';

  @override
  Widget? buildHelp(
    BuildContext context,
    ForgeToolCopy copy, {
    required Future<void> Function() checkAgain,
  }) => null;
}

/// A module that contributes [tool].
class _ToolModule extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _ToolModule(this.tool);

  final _Tool tool;

  @override
  String get displayName => 'Tool module';
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
  late final List<ForgeModuleExtra> ownExtras = [
    ForgeExternalToolsExtra([tool]),
  ];
}

Future<DefaultShellApi> _openShell(
  WidgetTester tester,
  ForgeMemoryStateStore store, {
  _Tool? tool,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: const {},
    appName: 'Files and tools',
    navigatorKey: GlobalKey<NavigatorState>(),
    stateStore: store,
  );
  shell.registerModule(TomForgeShellModule());
  if (tool != null) shell.registerModule(_ToolModule(tool));
  shell.applications.add(
    ForgeApplication(
      id: 'filesAndTools',
      title: 'Files and tools',
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('the file types description is valid', () {
    expect(_F.description.problems(), isEmpty);
  });

  testWidgets('file types: the built-in associations are in effect, a '
      'change reaches the shell, a removed one is cleared there', (
    tester,
  ) async {
    final store = ForgeMemoryStateStore();
    final shell = await _openShell(tester, store);
    final prefs = ForgePreferencesService.forStore(store);
    final values = _valuesOf(tester);
    expect(find.text('File Types'), findsWidgets);
    expect(values.valueOf(_F.associations)['.md'], 'md');
    expect(values.valueOf(_F.associations)['*'], 'plaintext');

    expect(
      await values.set(_F.associations, {
        ..._F.defaultAssociations,
        '.txt': 'md',
      }),
      isNull,
    );
    await _settle(tester, store);
    expect(prefs.fileTypeDefaultEditors['.txt'], 'md');
    expect(shell.getFileTypeDefaults()['.txt'], 'md');
    expect(
      (jsonDecode(store.snapshot()['forge.files.typeDefaults']! as String)
          as Map)['.txt'],
      'md',
    );

    expect(await values.set(_F.associations, _F.defaultAssociations), isNull);
    await _settle(tester, store);
    expect(prefs.fileTypeDefaultEditors.containsKey('.txt'), isFalse);
    expect(shell.getFileTypeDefaults().containsKey('.txt'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('file types: an existing user\'s associations are read', (
    tester,
  ) async {
    final store = ForgeMemoryStateStore(
      initial: {
        'forge.files.typeDefaults': jsonEncode({'.md': 'plaintext', '*': 'md'}),
      },
    );
    await _openShell(tester, store);
    final map = _valuesOf(tester).valueOf(_F.associations);
    expect(map['.md'], 'plaintext');
    expect(map['*'], 'md');
    expect(map['.dart'], 'dart', reason: 'the built-in ones stay under it');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('external tools: a module\'s tool is a path setting kept as '
      'forge.tools.<id>.path; its check is the detector, its help the '
      'help panel', (tester) async {
    final store = ForgeMemoryStateStore();
    final tool = _Tool();
    await _openShell(tester, store, tool: tool);
    final prefs = ForgePreferencesService.forStore(store);
    final values = _valuesOf(tester);
    expect(find.text('External Tools'), findsWidgets);
    final setting = _T.settingOf(tool);

    expect(await values.set(setting, '/opt/Fake.app'), isNull);
    await _settle(tester, store);
    expect(prefs.externalToolPath('fake'), '/opt/Fake.app');
    expect(store.snapshot()['forge.tools.fake.path'], '/opt/Fake.app');

    await values.reset(setting);
    await _settle(tester, store);
    expect(prefs.externalToolPath('fake'), isNull);
    expect(store.snapshot().containsKey('forge.tools.fake.path'), isFalse);

    // The detector: the tool's check, with where to get it while missing.
    final hooks = _T.hooks([tool]);
    final detector = hooks.detector(_T.detectorOf(tool))!;
    final context = ForgeSettingContext(
      setting: setting,
      value: '',
      hooks: hooks,
    );
    final missing = await detector.check(context, '', setting.hints);
    expect(missing.level, ForgeStatusLevel.error);
    expect(missing.message?.fallback, 'Not found');
    expect(missing.reason, 'not found', reason: 'the copy\'s own reason');
    final detected = await detector.detect(context, setting.hints);
    expect(detected.single.version, '2.0');

    // The help panel: the tool's own help for the copy last checked.
    final help = _T.buildHelpPanel(
      [tool],
      tester.element(find.byType(ForgeConfigurationScope).first),
      _T.helpPanelOf(tool),
      () {},
    );
    expect((help! as Text).data, 'help for missing');

    // Without help of its own: where to get it, while it is missing.
    final plain = _PlainTool();
    await _T
        .hooks([plain])
        .detector(_T.detectorOf(plain))!
        .check(context, '', setting.hints);
    final download = _T.buildHelpPanel(
      [plain],
      tester.element(find.byType(ForgeConfigurationScope).first),
      _T.helpPanelOf(plain),
      () {},
    );
    expect(
      (download! as SelectableText).data,
      'Download: https://example.org/fake',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}

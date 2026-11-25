// The shell's own Shell and Terminal options are a configuration description
// (ForgeShellConfiguration): shown as tiles in the configuration side panel,
// kept under the keys and in the encodings ForgePreferencesService always
// wrote (so stored preferences load unchanged), and changing them still does
// what the hand-written sections did.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';

/// Preferences as today's ForgePreferencesService stores them.
final _stored = <String, Object?>{
  'forge.appearance.themeMode': 'light',
  'forge.appearance.highContrast': true,
  'forge.appearance.reduceMotion': true,
  'forge.startup.maxRecentWorkspaces': 7,
  'forge.search.config': jsonEncode(
    const ForgeSearchConfig(
      excludedExtensions: {'png', 'lock'},
      excludedDirectories: {'build'},
      fileSizeLimit: 5 * 1024 * 1024,
      excludeHiddenDirectories: false,
      excludeGitIgnored: true,
      maxFileResults: 80,
    ).toJson(),
  ),
  'forge.layout.dim.panelContentMinWidth': 420.0,
  'forge.layout.dim.leftPanelDefaultWidth': 300.0,
  'forge.layout.dim.rightPanelDefaultWidth': 260.0,
  'forge.layout.dim.bottomPanelDefaultHeight': 180.0,
  'forge.layout.dim.dividerHitTarget': 12.0,
  'forge.terminal.defaultShell': '/bin/zsh',
  'forge.terminal.shellPaths': jsonEncode(['/bin/zsh', '/bin/bash']),
  'forge.terminal.startFolder': 'home',
  'forge.terminal.scrollbackLines': 5000,
  'forge.terminal.fontFamily': 'Menlo',
  'forge.terminal.fontSize': 13.0,
};

typedef _C = ForgeShellConfiguration;

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

/// Scrolls [finder] into view in the configuration tile's own scroll view.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    80,
    scrollable: find
        .ancestor(of: finder, matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

Future<DefaultShellApi> _openSettings(
  WidgetTester tester,
  ForgeMemoryStateStore store, {
  double? leftWidth,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: const {},
    appName: 'Shell configuration',
    navigatorKey: GlobalKey<NavigatorState>(),
    stateStore: store,
  );
  shell.registerModule(TomForgeShellModule());
  shell.applications.add(
    ForgeApplication(
      id: 'shellConfiguration',
      title: 'Shell configuration',
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
  if (leftWidth != null) {
    (shell.layout as DefaultLayoutController).setPanelSize(
      ForgePanelLocation.left,
      leftWidth,
    );
  }
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

  test('the description is valid: unique ids, known kinds, its hooks '
      'supplied', () {
    expect(_C.description.problems(hooks: _C.hooks()), isEmpty);
    expect(
      [for (final s in _C.description.settings) s.storage.binding],
      everyElement(
        anyOf(
          ForgePreferencesSettingBinding.bindingId,
          ForgeConfigSettingBinding.bindingId,
        ),
      ),
    );
  });

  group('compatibility with the stored preferences', () {
    late ForgeMemoryStateStore store;
    late ForgePreferencesService prefs;
    late DefaultConfigManager config;
    late ForgeConfigurationValues values;

    setUp(() async {
      store = ForgeMemoryStateStore(initial: _stored);
      prefs = ForgePreferencesService(stateStore: store);
      await prefs.load();
      config = DefaultConfigManager();
      values = forgeShellConfigurationValues(prefs, config: config);
      await values.load();
    });

    tearDown(() => values.dispose());

    test('today\'s stored documents are read unchanged', () {
      expect(values.problems, isEmpty);
      expect(values.valueOf(_C.themeMode), 'light');
      expect(values.valueOf(_C.highContrast), isTrue);
      expect(values.valueOf(_C.reduceMotion), isTrue);
      expect(values.valueOf(_C.maxRecentWorkspaces), 7);
      expect(values.valueOf(_C.searchExcludedExtensions), ['lock', 'png']);
      expect(values.valueOf(_C.searchExcludedDirectories), ['build']);
      expect(values.valueOf(_C.searchFileSizeLimit), 5 * 1024 * 1024);
      expect(_C.searchFileSizeLimit.toShown(5 * 1024 * 1024), 5);
      expect(values.valueOf(_C.searchHideHiddenDirectories), isFalse);
      expect(values.valueOf(_C.searchUseGitIgnore), isTrue);
      expect(values.valueOf(_C.searchMaxFileResults), 80);
      expect(values.valueOf(_C.panelContentMinWidth), 420);
      expect(values.valueOf(_C.leftPanelDefaultWidth), 300);
      expect(values.valueOf(_C.rightPanelDefaultWidth), 260);
      expect(values.valueOf(_C.bottomPanelDefaultHeight), 180);
      expect(values.valueOf(_C.dividerHitTarget), 12);
      expect(values.valueOf(_C.terminalDefaultShell), '/bin/zsh');
      expect(values.valueOf(_C.terminalShellPaths), ['/bin/zsh', '/bin/bash']);
      expect(values.valueOf(_C.terminalStartFolder), 'home');
      expect(values.valueOf(_C.terminalScrollbackLines), 5000);
      expect(values.valueOf(_C.terminalFontFamily), 'Menlo');
      expect(values.valueOf(_C.terminalFontSize), 13);
      // The auto-save of the configuration manager (defaults).
      expect(values.valueOf(_C.autoSaveEnabled), isTrue);
      expect(values.valueOf(_C.autoSaveIdleDelay), 2);
      expect(values.valueOf(_C.autoSaveOnFocusLoss), isTrue);
    });

    test('writes go to the same keys in the same encodings', () async {
      expect(await values.set(_C.themeMode, 'system'), isNull);
      expect(await values.set(_C.highContrast, false), isNull);
      expect(await values.set(_C.reduceMotion, false), isNull);
      expect(await values.set(_C.maxRecentWorkspaces, 12), isNull);
      expect(
        await values.set(_C.searchFileSizeLimit, 20 * 1024 * 1024),
        isNull,
      );
      expect(await values.set(_C.searchMaxFileResults, 99), isNull);
      expect(
        await values.set(_C.searchExcludedExtensions, ['exe', 'png']),
        isNull,
      );
      expect(await values.set(_C.dividerHitTarget, 21.0), isNull);
      expect(await values.set(_C.terminalDefaultShell, ''), isNull);
      expect(await values.set(_C.terminalShellPaths, ['/bin/fish']), isNull);
      expect(await values.set(_C.terminalStartFolder, 'lastUsed'), isNull);
      expect(await values.set(_C.terminalScrollbackLines, 2500), isNull);
      expect(await values.set(_C.terminalFontFamily, 'Courier New'), isNull);
      expect(await values.set(_C.terminalFontSize, 16.0), isNull);
      await values.flushed();
      await store.flushed();

      final snapshot = store.snapshot();
      expect(snapshot['forge.appearance.themeMode'], 'system');
      expect(snapshot['forge.appearance.highContrast'], false);
      expect(snapshot['forge.appearance.reduceMotion'], false);
      expect(snapshot['forge.startup.maxRecentWorkspaces'], 12);
      // The search configuration stays one JSON text, the limit in bytes.
      final search = snapshot['forge.search.config'];
      expect(search, isA<String>());
      final decoded = jsonDecode(search! as String) as Map<String, dynamic>;
      expect(decoded['fileSizeLimit'], 20 * 1024 * 1024);
      expect(decoded['maxFileResults'], 99);
      expect(decoded['excludedExtensions'], ['exe', 'png']);
      expect(decoded['excludedDirectories'], ['build']);
      expect(decoded['excludeHiddenDirectories'], false);
      expect(snapshot['forge.layout.dim.dividerHitTarget'], 21.0);
      // The empty default shell is the platform's: the key goes.
      expect(snapshot.containsKey('forge.terminal.defaultShell'), isFalse);
      expect(snapshot['forge.terminal.shellPaths'], jsonEncode(['/bin/fish']));
      expect(snapshot['forge.terminal.startFolder'], 'lastUsed');
      expect(snapshot['forge.terminal.scrollbackLines'], 2500);
      expect(snapshot['forge.terminal.fontFamily'], 'Courier New');
      expect(snapshot['forge.terminal.fontSize'], 16.0);

      // The service reads them back as it always did.
      final again = ForgePreferencesService(stateStore: store);
      await again.load();
      expect(again.themeMode, ThemeMode.system);
      expect(again.searchConfig.fileSizeLimit, 20 * 1024 * 1024);
      expect(again.terminalDefaultShell, isNull);
      expect(again.terminalShellPaths, ['/bin/fish']);
      expect(again.terminalFontSize, 16.0);
      expect(again.dividerHitTarget, 21.0);
    });

    test('the preferences service is the one changed: a later save writes '
        'nothing stale back', () async {
      await values.set(_C.terminalFontFamily, 'Monaco');
      await values.set(_C.searchMaxFileResults, 33);
      expect(prefs.terminalFontFamily, 'Monaco');
      expect(prefs.searchConfig.maxFileResults, 33);
      await prefs.save();
      await store.flushed();
      expect(store.snapshot()['forge.terminal.fontFamily'], 'Monaco');
    });

    test('a reset puts the default back', () async {
      await values.reset(_C.searchExcludedExtensions);
      await values.reset(_C.terminalFontSize);
      await values.flushed();
      expect(
        prefs.searchConfig.excludedExtensions,
        const ForgeSearchConfig().excludedExtensions,
      );
      expect(
        values.valueOf(_C.searchExcludedExtensions),
        _C.searchExcludedExtensions.defaultValue,
      );
      expect(prefs.terminalFontSize, 14.0);
      // The other search fields are kept.
      expect(prefs.searchConfig.maxFileResults, 80);
    });

    test('a change made elsewhere reaches the values', () async {
      prefs.terminalScrollbackLines = 777;
      config.setCurrent(
        const ForgeConfig(
          autoSave: AutoSaveConfig(idleDelay: Duration(seconds: 9)),
        ),
        key: 'autoSave',
      );
      await pumpEventQueue();
      expect(values.valueOf(_C.terminalScrollbackLines), 777);
      expect(values.valueOf(_C.autoSaveIdleDelay), 9);
    });

    test('auto save is the configuration manager\'s', () async {
      await values.set(_C.autoSaveIdleDelay, 5);
      await values.set(_C.autoSaveOnFocusLoss, false);
      await values.flushed();
      expect(config.current.autoSave.idleDelay, const Duration(seconds: 5));
      expect(config.current.autoSave.saveOnFocusLoss, isFalse);
      expect(config.current.autoSave.enabled, isTrue);
    });

    test('the terminal font list is a hook of the description', () async {
      final choices = await values.choicesFor(_C.terminalFontFamily);
      expect(choices.map((c) => c.value), contains('Menlo'));
    });
  });

  group('in the configuration side panel', () {
    testWidgets('every Shell and Terminal setting is an entry of its section', (
      tester,
    ) async {
      final store = ForgeMemoryStateStore();
      await _openSettings(tester, store);

      // Shell is the section open at first.
      expect(
        find.byKey(
          const ValueKey('forge.configuration.tile.forge.shell/shell'),
        ),
        findsOneWidget,
      );
      for (final setting in _C.shellSection.settings) {
        expect(_entry(setting), findsOneWidget, reason: setting.id);
      }
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Quick Access'), findsOneWidget);
      expect(find.text('Auto Save'), findsOneWidget);
      expect(find.text('Layout'), findsOneWidget);

      await tester.tap(find.text('Terminal').first);
      await tester.pumpAndSettle();
      for (final setting in _C.terminalSection.settings) {
        expect(_entry(setting), findsOneWidget, reason: setting.id);
      }
      expect(find.text('Default Shell'), findsOneWidget);
      expect(find.text('Font & Display'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('changing them does what the old sections did: the theme, '
        'reduce motion, auto save and the terminal settings', (tester) async {
      final store = ForgeMemoryStateStore();
      final shell = await _openSettings(tester, store);
      final prefs = ForgePreferencesService.forStore(store);
      addTearDown(() => ForgeAnimations.reduceMotion = false);

      // The theme: the preference the application's theme follows.
      var notified = 0;
      void count() => notified++;
      prefs.addListener(count);
      addTearDown(() => prefs.removeListener(count));
      final light = find.descendant(
        of: _entry(_C.themeMode),
        matching: find.text('Light'),
      );
      await _reveal(tester, light);
      await tester.tap(light);
      await _settle(tester, store);
      expect(prefs.themeMode, ThemeMode.light);
      expect(notified, greaterThan(0));
      expect(store.snapshot()['forge.appearance.themeMode'], 'light');

      // Reduce motion reaches the shell's animations.
      final reduceMotion = find.descendant(
        of: _entry(_C.reduceMotion),
        matching: find.byType(Switch),
      );
      await _reveal(tester, reduceMotion);
      await tester.tap(reduceMotion);
      await _settle(tester, store);
      expect(prefs.reduceMotion, isTrue);
      expect(ForgeAnimations.reduceMotion, isTrue);
      expect(store.snapshot()['forge.appearance.reduceMotion'], true);

      // Auto save reaches the shell's configuration.
      final idleDelay = find.descendant(
        of: _entry(_C.autoSaveIdleDelay),
        matching: find.byType(TextField),
      );
      await _reveal(tester, idleDelay);
      await tester.enterText(idleDelay, '7');
      await _settle(tester, store);
      expect(
        shell.config.current.autoSave.idleDelay,
        const Duration(seconds: 7),
      );

      // The search configuration the search view is given.
      final sizeLimit = find.descendant(
        of: _entry(_C.searchFileSizeLimit),
        matching: find.byType(TextField),
      );
      await _reveal(tester, sizeLimit);
      await tester.enterText(sizeLimit, '3');
      await _settle(tester, store);
      expect(prefs.searchConfig.fileSizeLimit, 3 * 1024 * 1024);

      // The terminal settings.
      await tester.tap(find.text('Terminal').first);
      await tester.pumpAndSettle();
      final fontSize = find.descendant(
        of: _entry(_C.terminalFontSize),
        matching: find.byType(TextField),
      );
      await _reveal(tester, fontSize);
      await tester.enterText(fontSize, '18');
      await _settle(tester, store);
      expect(prefs.terminalFontSize, 18.0);
      expect(store.snapshot()['forge.terminal.fontSize'], 18.0);
      expect(
        await _valuesOf(tester).set(_C.terminalFontFamily, 'Monaco'),
        isNull,
      );
      await _settle(tester, store);
      expect(prefs.terminalFontFamily, 'Monaco');
      expect(store.snapshot()['forge.terminal.fontFamily'], 'Monaco');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('in a 240 px left panel every control of a row is on '
        'screen and answers a tap', (tester) async {
      final store = ForgeMemoryStateStore();
      await _openSettings(tester, store, leftWidth: 240);
      // The side panel is laid out at the content minimum width (400 px)
      // and clipped to the panel's own width; what is on screen is the clip.
      final panel = tester.getRect(
        find
            .ancestor(
              of: find.byType(ForgeSidePanelWidget).first,
              matching: find.byType(ClipRect),
            )
            .first,
      );
      expect(panel.width, lessThan(250));
      final visibleRight = panel.right;

      Future<void> showAndTap(Finder control) async {
        expect(control, findsOneWidget);
        await tester.scrollUntilVisible(
          control,
          80,
          scrollable: find
              .ancestor(of: control, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(control).right, lessThanOrEqualTo(visibleRight));
        await tester.tap(control);
        await _settle(tester, store);
      }

      await showAndTap(
        find.descendant(
          of: _entry(_C.reduceMotion),
          matching: find.byType(Switch),
        ),
      );
      expect(store.snapshot()['forge.appearance.reduceMotion'], true);
      addTearDown(() => ForgeAnimations.reduceMotion = false);

      await tester.tap(find.text('Terminal').first);
      await tester.pumpAndSettle();
      final paths = find.descendant(
        of: _entry(_C.terminalShellPaths),
        matching: find.byType(TextField),
      );
      await tester.enterText(paths, '/bin/fish');
      await showAndTap(
        find.descendant(
          of: _entry(_C.terminalShellPaths),
          matching: find.widgetWithIcon(IconButton, Icons.add),
        ),
      );
      expect(
        jsonDecode(store.snapshot()['forge.terminal.shellPaths']! as String),
        contains('/bin/fish'),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('quick open\'s section indices open the same sections', (
      tester,
    ) async {
      final expand = ValueNotifier<int?>(null);
      addTearDown(expand.dispose);
      final store = ForgeMemoryStateStore();
      final prefs = ForgePreferencesService(stateStore: store);
      await tester.runAsync(prefs.load);
      // An editor type's description, as the Dart editor's names it.
      final dartEditor = ForgeConfigurationDescription(
        id: 'forge.editor.dart',
        title: const ForgeText('test.dart', 'Dart Editor'),
        sections: [
          ForgeSettingsSection(
            id: 'editor',
            title: const ForgeText('test.dart.section', 'Dart Editor'),
            order: 2,
            settings: ForgeEditorSettings.textGroups('dart'),
          ),
        ],
      );
      final values = forgeShellConfigurationValues(
        prefs,
        descriptions: [dartEditor],
      );
      addTearDown(values.dispose);
      await tester.runAsync(values.load);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 1600,
              child: ForgeConfigurationPanel(
                preferencesService: prefs,
                configurationValues: values,
                expandSection: expand,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const shellTile = ValueKey('forge.configuration.tile.forge.shell/shell');
      const terminalTile = ValueKey(
        'forge.configuration.tile.forge.shell/terminal',
      );
      expect(find.byKey(shellTile), findsOneWidget);

      expand.value = ForgeConfigurationPanel.sectionIndexTerminal;
      await tester.pumpAndSettle();
      expect(find.byKey(terminalTile), findsOneWidget);
      expect(find.byKey(shellTile), findsNothing);
      expect(expand.value, isNull);

      expand.value = ForgeConfigurationPanel.sectionIndexShell;
      await tester.pumpAndSettle();
      expect(find.byKey(shellTile), findsOneWidget);
      expect(find.byKey(terminalTile), findsNothing);

      // 2: the Dart editor's section, its own description now.
      expand.value = 2;
      await tester.pumpAndSettle();
      expect(find.byKey(shellTile), findsNothing);
      expect(
        find.byKey(
          const ValueKey('forge.configuration.tile.forge.editor.dart/editor'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}

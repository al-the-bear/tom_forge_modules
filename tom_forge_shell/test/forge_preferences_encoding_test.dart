import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tom_editors_shared/text_types.dart' show ForgeTextSettings;
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeSearchConfig;
import 'package:tom_forge_shell/tom_forge_shell.dart';

import 'support/legacy_forge_preferences_service.dart';

/// Sets one value of every preference on [p] — a [ForgePreferencesService]
/// or the [LegacyForgePreferencesService] it replaced; both have the same
/// members.
Future<void> _fill(dynamic p) async {
  await p.addRecentWorkspace('/ws/b');
  await p.addRecentWorkspace('/ws/a');
  p.startupPreferences.lastConfigMode = 'central';
  p.startupPreferences.rememberSettings = false;
  p.maxRecentWorkspaces = 7;
  p.centralConfigDirectory = '/cfg';
  p.setLayoutPanelSize('left', 312.5);
  p.setLayoutPanelSize('bottom', 200.0);
  p.setLayoutPanelVisibility('left', true);
  p.setLayoutPanelVisibility('right', false);
  p.setLayoutOpenEditors(['file:///ws/a/x.dart', 'file:///ws/a/y.md']);
  p.setLayoutSnapshot(<String, dynamic>{
    'panels': {
      'left': {'size': 320.0, 'isVisible': true},
    },
    'activeMiddlePanelIndex': 1,
    'middlePanelFlex': [1.0, 1.4],
  });
  p.themeMode = ThemeMode.light;
  p.highContrast = true;
  p.terminalDefaultShell = '/bin/zsh';
  p.terminalShellPaths = ['/bin/zsh', '/bin/bash'];
  p.terminalStartFolder = 'home';
  p.terminalScrollbackLines = 5000;
  p.terminalFontFamily = 'Menlo';
  p.terminalFontSize = 15.5;
  p.panelContentMinWidth = 420.0;
  p.leftPanelDefaultWidth = 300.0;
  p.rightPanelDefaultWidth = 310.0;
  p.bottomPanelDefaultHeight = 220.0;
  p.dividerHitTarget = 16.0;
  p.reduceMotion = true;
  p.setActionBarActions('dart', ['format', 'run']);
  p.setEditorTextSettings(
    'md',
    const ForgeTextSettings(
      fontFamily: 'Fira Code',
      fontSize: 16,
      lineHeight: 1.6,
      tabSize: 4,
      wordWrap: false,
      maxUndoHistory: 250,
    ),
  );
  p.setEditorSpecificConfig('md', <String, dynamic>{
    'preview': true,
    'width': 3,
  });
  p.setFileTypeDefaultEditor('txt', 'plaintext');
  p.setFileTypeDefaultEditor('.JSON', 'yaml');
  p.setShortcutOverride(
    'editor.find',
    const ForgeShortcutKey(
      key: LogicalKeyboardKey.keyK,
      primaryModifier: true,
      shift: true,
    ),
  );
  p.setChordOverride(
    'editor.fold',
    const ForgeChordKey(
      firstKey: ForgeShortcutKey(
        key: LogicalKeyboardKey.keyK,
        primaryModifier: true,
      ),
      secondKey: ForgeShortcutKey(key: LogicalKeyboardKey.digit0),
    ),
  );
  p.addDeletedBinding('editor.gone');
  p.searchConfig = const ForgeSearchConfig(
    excludedExtensions: {'.lock'},
    fileSizeLimit: 1024,
    maxFileResults: 50,
  );
  await p.setExternalToolPath('pandoc', '/opt/pandoc/bin/pandoc');
  await p.setExternalToolPath('office', '/Applications/Office.app');
}

/// Every stored shared_preferences value, by key.
Future<Map<String, Object?>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)};
}

/// Every value [p] answers, as JSON-comparable data.
Map<String, Object?> _view(dynamic p) => <String, Object?>{
  'lastWorkspacePath': p.startupPreferences.lastWorkspacePath,
  'lastConfigMode': p.startupPreferences.lastConfigMode,
  'rememberSettings': p.startupPreferences.rememberSettings,
  'recentWorkspaces': p.startupPreferences.recentWorkspaces,
  'maxRecentWorkspaces': p.maxRecentWorkspaces,
  'centralConfigDirectory': p.centralConfigDirectory,
  'layoutPanelSizes': p.layoutPanelSizes,
  'layoutPanelVisibility': p.layoutPanelVisibility,
  'layoutOpenEditors': p.layoutOpenEditors,
  'layoutSnapshot': jsonEncode(p.layoutSnapshot),
  'themeMode': '${p.themeMode}',
  'highContrast': p.highContrast,
  'terminalDefaultShell': p.terminalDefaultShell,
  'terminalShellPaths': p.terminalShellPaths,
  'terminalStartFolder': p.terminalStartFolder,
  'terminalScrollbackLines': p.terminalScrollbackLines,
  'terminalFontFamily': p.terminalFontFamily,
  'terminalFontSize': p.terminalFontSize,
  'panelContentMinWidth': p.panelContentMinWidth,
  'leftPanelDefaultWidth': p.leftPanelDefaultWidth,
  'rightPanelDefaultWidth': p.rightPanelDefaultWidth,
  'bottomPanelDefaultHeight': p.bottomPanelDefaultHeight,
  'dividerHitTarget': p.dividerHitTarget,
  'reduceMotion': p.reduceMotion,
  'actionBarActions': p.actionBarActions,
  'editorTextSettings': {
    for (final e in (p.editorTextSettings as Map).entries)
      e.key:
          '${e.value.fontFamily}/${e.value.fontSize}/${e.value.lineHeight}/'
          '${e.value.tabSize}/${e.value.wordWrap}/${e.value.maxUndoHistory}',
  },
  'editorSpecificConfig': p.getEditorSpecificConfig('md'),
  'fileTypeDefaultEditors': p.fileTypeDefaultEditors,
  'shortcutOverrides': {
    for (final e in (p.shortcutOverrides as Map).entries)
      e.key:
          '${e.value.key.keyId}/${e.value.primaryModifier}/'
          '${e.value.control}/${e.value.shift}/${e.value.alt}',
  },
  'chordOverrides': {
    for (final e in (p.chordOverrides as Map).entries)
      e.key: '${e.value.firstKey.key.keyId}/${e.value.secondKey.key.keyId}',
  },
  'deletedBindings': (p.deletedBindings as Set).toList(),
  'searchConfig': jsonEncode(p.searchConfig.toJson()),
  'pandoc': p.externalToolPath('pandoc'),
  'office': p.externalToolPath('office'),
};

/// A shared_preferences platform that counts every call and fails it.
class _ThrowingPreferencesStore extends SharedPreferencesStorePlatform {
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('shared_preferences was called');
  }

  @override
  Future<bool> clear() async => _fail();

  @override
  Future<Map<String, Object>> getAll() async => _fail();

  @override
  Future<bool> remove(String key) async => _fail();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      _fail();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForgePreferencesService over shared_preferences', () {
    test('stores every key with the same key and the same value encoding '
        'as the service before the state store', () async {
      SharedPreferences.setMockInitialValues({});
      final legacy = LegacyForgePreferencesService();
      await legacy.load();
      await _fill(legacy);
      await legacy.save();
      final before = await _stored();

      SharedPreferences.setMockInitialValues({});
      final current = ForgePreferencesService();
      await current.load();
      await _fill(current);
      await current.save();
      await current.flushed();
      final after = await _stored();

      // The keys added since: the default editors by content type, kept
      // as a JSON map like the ones by extension.
      const added = {'forge.files.contentTypeDefaults'};
      expect(after.keys.toSet().difference(added), before.keys.toSet());
      expect(after['forge.files.contentTypeDefaults'], '{}');
      for (final key in before.keys) {
        expect(after[key], before[key], reason: key);
        expect(
          after[key].runtimeType,
          before[key].runtimeType,
          reason: '$key: the same shared_preferences type',
        );
      }
      // Every key the services know is in the comparison: the shell's 25
      // and the kit's 7, with two external tool paths.
      expect(before, hasLength(34));
    });

    test('loads what the service before the state store stored, '
        'unchanged', () async {
      SharedPreferences.setMockInitialValues({});
      final legacy = LegacyForgePreferencesService();
      await legacy.load();
      await _fill(legacy);
      await legacy.save();

      final reloadedLegacy = LegacyForgePreferencesService();
      await reloadedLegacy.load();
      final current = ForgePreferencesService();
      await current.load();

      expect(_view(current), _view(reloadedLegacy));
      expect(current.isLoaded, isTrue);
    });

    test('a value set before load is not written, and load reads the stored '
        'value over it', () async {
      SharedPreferences.setMockInitialValues({
        'forge.appearance.themeMode': 'light',
      });
      final service = ForgePreferencesService();
      service.themeMode = ThemeMode.system;
      service.highContrast = true;
      await service.flushed();
      expect((await _stored())['forge.appearance.themeMode'], 'light');
      expect(
        (await _stored()).containsKey('forge.appearance.highContrast'),
        isFalse,
      );
      await service.load();
      expect(service.themeMode, ThemeMode.light);
      expect(service.highContrast, isFalse);
    });
  });

  group('ForgePreferencesService over a given store', () {
    late _ThrowingPreferencesStore platform;

    setUp(() {
      SharedPreferences.resetStatic();
      platform = _ThrowingPreferencesStore();
      SharedPreferencesStorePlatform.instance = platform;
    });

    tearDown(() {
      SharedPreferencesStorePlatform.instance =
          InMemorySharedPreferencesStore.empty();
      SharedPreferences.resetStatic();
    });

    test(
      'reads and writes every key through it, never shared_preferences',
      () async {
        final store = ForgeMemoryStateStore();
        final first = ForgePreferencesService(stateStore: store);
        await first.load();
        await _fill(first);
        await first.save();
        await first.flushed();

        final second = ForgePreferencesService(stateStore: store);
        await second.load();
        expect(_view(second), _view(first));
        expect(platform.calls, 0);
        // The keys and values are the shared_preferences ones.
        final stored = store.snapshot();
        expect(stored['forge.terminal.scrollbackLines'], 5000);
        expect(stored['forge.terminal.fontSize'], 15.5);
        expect(stored['forge.appearance.highContrast'], isTrue);
        expect(stored['forge.tools.pandoc.path'], '/opt/pandoc/bin/pandoc');
        expect(jsonDecode(stored['forge.layout.openEditors']! as String), [
          'file:///ws/a/x.dart',
          'file:///ws/a/y.md',
        ]);
      },
    );

    test('forStore answers the instance for its store and one service per '
        'other store', () {
      final store = ForgeMemoryStateStore();
      expect(
        ForgePreferencesService.forStore(
          ForgePreferencesService.instance.stateStore,
        ),
        same(ForgePreferencesService.instance),
      );
      final service = ForgePreferencesService.forStore(store);
      expect(service.stateStore, same(store));
      expect(ForgePreferencesService.forStore(store), same(service));
      expect(platform.calls, 0);
    });

    test('DefaultShellApi answers the store it is given, else the '
        'preferences singleton\'s', () {
      final store = ForgeMemoryStateStore();
      final given = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'given',
        navigatorKey: GlobalKey<NavigatorState>(),
        stateStore: store,
      );
      final standard = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'standard',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      expect(given.stateStore, same(store));
      expect(
        standard.stateStore,
        same(ForgePreferencesService.instance.stateStore),
      );
      expect(standard.stateStore, isA<ForgeSharedPreferencesStateStore>());
      expect(platform.calls, 0);
      given.dispose();
      standard.dispose();
    });
  });
}

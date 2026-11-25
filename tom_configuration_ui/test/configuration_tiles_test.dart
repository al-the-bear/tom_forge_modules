// The configuration tiles: a fake module describes its options, a test page
// arranges the tiles itself, edits go through the state-store port, reset,
// validation, labels through Tom Core's text resources, and the editor
// registry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomTextResourceProvider;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'support/demo_configuration.dart';

/// The field debounce of `tom_flutter_ui` (validation runs after it).
const _settle = Duration(milliseconds: 600);

Finder _entry(ForgeSetting<Object> setting) => find.byKey(
  ValueKey('forge.configuration.setting.${setting.storage.location}'),
);

/// A surface large enough for both tiles side by side.
void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _textFieldOf(ForgeSetting<Object> setting) =>
    find.descendant(of: _entry(setting), matching: find.byType(TextField));

void main() {
  late ForgeMemoryStateStore store;
  late DefaultKitApi api;
  late ForgeConfigurationValues values;

  Future<void> start(WidgetTester tester, {ThemeMode? themeMode}) async {
    _bigView(tester);
    store = ForgeMemoryStateStore();
    api = demoApi(store);
    values = ForgeConfigurationValues(
      store,
      descriptions: forgeConfigurationDescriptionsOf(api),
    );
    await tester.runAsync(values.load);
    await tester.pumpWidget(
      demoPage(
        forgeConfigurationTiles(values),
        themeMode: themeMode ?? ThemeMode.light,
      ),
    );
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(_settle);
    values.dispose();
    api.dispose();
  }

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  tearDown(TomTextResourceProvider.clearAppResourceProvider);

  group('the tiles of the collected descriptions', () {
    testWidgets('the module\'s description reaches the kit and the page', (
      tester,
    ) async {
      await start(tester);
      expect(forgeConfigurationDescriptionsOf(api), [demoDescription]);

      // One tile per section, in section order (editing 10, files 20).
      final tiles = tester
          .widgetList<ForgeConfigurationTile>(
            find.byType(ForgeConfigurationTile),
          )
          .toList();
      expect(tiles.map((t) => t.section.id), ['editing', 'files']);
      // The page arranges them: both in its Wrap.
      for (final tile in tiles) {
        expect(
          find.ancestor(of: find.byWidget(tile), matching: find.byType(Wrap)),
          findsOneWidget,
        );
      }

      for (final text in [
        'Editing',
        'Files',
        'Wrap long lines',
        'Tab size',
        'spaces',
        'Font size',
        'Theme',
        'Font family',
        'Language',
        'Notes',
        'Ignored folders',
        'Features',
        'SDK folder',
        'Accent colour',
        'File types',
        'Extension',
        'Editor',
        'build',
        '#2196F3',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('No editor', findRichText: true), findsNothing);
      await finish(tester);
    });

    testWidgets('every standard kind has an editor, a new kind registers one', (
      tester,
    ) async {
      final registry = ForgeSettingEditorRegistry.standard();
      expect(registry.kinds, containsAll(ForgeSettingKinds.all));

      const custom = _RatingSetting(
        id: 'rating',
        storage: ForgeSettingStorage('demo.rating'),
        label: ForgeText('demo.rating', 'Rating'),
        defaultValue: 2,
      );
      const description = ForgeConfigurationDescription(
        id: 'custom',
        title: ForgeText('custom', 'Custom'),
        sections: [
          ForgeSettingsSection(
            id: 'main',
            title: ForgeText('custom.main', 'Custom kind'),
            settings: [custom],
          ),
        ],
      );
      store = ForgeMemoryStateStore();
      values = ForgeConfigurationValues(store, descriptions: [description]);
      await tester.runAsync(values.load);
      _bigView(tester);

      // Without an editor for the kind: the tile says so.
      await tester.pumpWidget(demoPage(forgeConfigurationTiles(values)));
      expect(
        find.text('No editor for settings of the kind "rating".'),
        findsOneWidget,
      );

      // A registered editor is used; its value goes through the store.
      final extended = registry.copy()
        ..register(
          'rating',
          ForgeSettingEditor(
            (context, request) => TextButton(
              onPressed: () => request.onChanged((request.value as int) + 1),
              child: Text('stars: ${request.value}'),
            ),
          ),
        );
      expect(registry.editorFor('rating'), isNull);
      await tester.pumpWidget(
        demoPage(forgeConfigurationTiles(values, registry: extended)),
      );
      await tester.tap(find.text('stars: 2'));
      await tester.pump();
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.rating'], 3);
      await tester.pump();
      expect(find.text('stars: 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      values.dispose();
    });
  });

  group('editing writes through the state-store port', () {
    testWidgets('a number, read back by a new values service', (tester) async {
      await start(tester);
      await tester.enterText(_textFieldOf(sizeSetting), '8');
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.size'], 8);

      final again = ForgeConfigurationValues(
        store,
        descriptions: [demoDescription],
      );
      await tester.runAsync(again.load);
      expect(again.valueOf(sizeSetting), 8);
      again.dispose();
      await finish(tester);
    });

    testWidgets('a switch, a choice, a path-shared text and a list', (
      tester,
    ) async {
      await start(tester);
      await tester.tap(
        find.descendant(of: _entry(wrapSetting), matching: find.byType(Switch)),
      );
      await tester.pump(_settle);

      await tester.tap(
        find.descendant(of: _entry(themeSetting), matching: find.text('Dark')),
      );
      await tester.pump(_settle);

      await tester.enterText(_textFieldOf(fontSetting), 'Fira Code');
      await tester.pump(_settle);

      await tester.enterText(_textFieldOf(ignoredSetting), 'out');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(_settle);

      await tester.runAsync(values.flushed);
      final stored = store.snapshot();
      expect(stored['demo.wrap'], isTrue);
      expect(stored['demo.theme'], 'dark');
      expect(stored['demo.text'], {'fontFamily': 'Fira Code'});
      expect(stored['demo.ignored'], ['build', 'out']);
      await finish(tester);
    });

    testWidgets('a colour and a map entry', (tester) async {
      await start(tester);
      await tester.enterText(_textFieldOf(accentSetting), '#FF0000');
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.accent'], 0xFFFF0000);

      final mapFields = _textFieldOf(associationsSetting);
      await tester.enterText(mapFields.last, '.txt');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.associations'], {
        '.md': 'markdown',
        '.txt': 'markdown',
      });
      await finish(tester);
    });
  });

  group('the application\'s services', () {
    testWidgets('the path picker fills a path setting', (tester) async {
      _bigView(tester);
      store = ForgeMemoryStateStore();
      values = ForgeConfigurationValues(store, descriptions: [demoDescription]);
      await tester.runAsync(values.load);
      ForgePathSetting? asked;
      await tester.pumpWidget(
        demoPage([
          ForgeConfigurationScope(
            values: values,
            pickPath: (setting, current) async {
              asked = setting;
              return '/opt/sdk';
            },
            child: const ForgeConfigurationTile(section: filesSection),
          ),
        ]),
      );
      await tester.tap(find.text('Browse…'));
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(asked, sdkSetting);
      expect(store.snapshot()['demo.sdk'], '/opt/sdk');
      await tester.pumpWidget(const SizedBox());
      values.dispose();
    });

    test('section icons are constants the resolver knows', () {
      expect(forgeMaterialIconFor(const ForgeIconRef(0xe21a)), Icons.edit);
      expect(forgeMaterialIconFor(const ForgeIconRef(0x1)), isNull);
      expect(
        forgeMaterialIconFor(const ForgeIconRef(0xe21a, fontFamily: 'Other')),
        isNull,
      );
    });

    testWidgets('the trail logs edits while its switch is on', (tester) async {
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      kConfigurationUiDebug = true;
      try {
        await start(tester);
        await tester.enterText(_textFieldOf(sizeSetting), '99');
        await tester.pump(_settle);
        await finish(tester);
      } finally {
        kConfigurationUiDebug = false;
        debugPrint = previous;
      }
      expect(lines.any((l) => l.startsWith('[CU ')), isTrue);
      expect(
        lines.any((l) => l.contains('commit demo.size: ')),
        isTrue,
        reason: lines.join('\n'),
      );
    });
  });

  group('reset and validation', () {
    testWidgets('reset to default removes the stored value', (tester) async {
      await start(tester);
      await tester.enterText(_textFieldOf(sizeSetting), '8');
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.size'], 8);

      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.reset.demo.size')),
      );
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(store.snapshot().containsKey('demo.size'), isFalse);
      expect(values.valueOf(sizeSetting), 4);
      final field = tester.widget<TextField>(_textFieldOf(sizeSetting));
      expect(field.controller!.text, '4');
      await finish(tester);
    });

    testWidgets('an invalid value is refused with its message', (tester) async {
      await start(tester);
      await tester.enterText(_textFieldOf(sizeSetting), '99');
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(find.text('At most 16.'), findsOneWidget);
      expect(store.snapshot().containsKey('demo.size'), isFalse);
      expect(values.valueOf(sizeSetting), 4);

      // A valid value takes the message away.
      await tester.enterText(_textFieldOf(sizeSetting), '12');
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(find.text('At most 16.'), findsNothing);
      expect(store.snapshot()['demo.size'], 12);

      // Reset also drops a refused text the editor still shows.
      await tester.enterText(_textFieldOf(fontSetting), '');
      await tester.pump(_settle);
      expect(find.text('A value is required.'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey('forge.configuration.reset.demo.text/fontFamily'),
        ),
      );
      await tester.pump(_settle);
      expect(find.text('A value is required.'), findsNothing);
      expect(
        tester.widget<TextField>(_textFieldOf(fontSetting)).controller!.text,
        'monospace',
      );
      await finish(tester);
    });

    testWidgets('a stored value the setting refuses is reported', (
      tester,
    ) async {
      _bigView(tester);
      store = ForgeMemoryStateStore(initial: {'demo.size': 40});
      values = ForgeConfigurationValues(store, descriptions: [demoDescription]);
      await tester.runAsync(values.load);
      await tester.pumpWidget(demoPage(forgeConfigurationTiles(values)));
      expect(find.text('At most 16.'), findsOneWidget);
      expect(values.valueOf(sizeSetting), 4);
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.reset.demo.size')),
      );
      await tester.pump(_settle);
      await tester.runAsync(values.flushed);
      expect(find.text('At most 16.'), findsNothing);
      expect(store.snapshot().containsKey('demo.size'), isFalse);
      await tester.pumpWidget(const SizedBox());
      values.dispose();
    });
  });

  group('labels through Tom Core\'s text resources', () {
    testWidgets('a translated key, a missing key, and a switched bundle', (
      tester,
    ) async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'demo.size': 'Tabulatorbreite',
          'forge.configuration.validation.max': 'Höchstens {max}.',
        }),
      );
      await start(tester);
      expect(find.text('Tabulatorbreite'), findsOneWidget);
      expect(find.text('Tab size'), findsNothing);
      // No translation: the fallback.
      expect(find.text('Font family'), findsOneWidget);

      await tester.enterText(_textFieldOf(sizeSetting), '99');
      await tester.pump(_settle);
      expect(find.text('Höchstens 16.'), findsOneWidget);

      // Another bundle: the tile follows it.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'demo.size': 'Largeur de tabulation',
          'demo.font': 'Police',
        }),
      );
      await tester.pump();
      expect(find.text('Largeur de tabulation'), findsOneWidget);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Tabulatorbreite'), findsNothing);
      expect(find.text('At most 16.'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('with no bundle installed: the fallbacks', (tester) async {
      TomTextResourceProvider.clearAppResourceProvider();
      expect(ForgeConfigurationLabels.resourcesInstalled, isFalse);
      expect(ForgeConfigurationLabels.resolve(sizeSetting.label), 'Tab size');
      await start(tester);
      expect(find.text('Tab size'), findsOneWidget);
      expect(ForgeConfigurationLabels.resourcesInstalled, isTrue);
      await finish(tester);
    });
  });

  group('the tile style', () {
    testWidgets('spacing, padding and header come from the style', (
      tester,
    ) async {
      store = ForgeMemoryStateStore();
      values = ForgeConfigurationValues(store, descriptions: [demoDescription]);
      await tester.runAsync(values.load);
      const style = ForgeConfigurationTileStyle(
        padding: EdgeInsets.all(20),
        showHeader: false,
      );
      await tester.pumpWidget(
        demoPage([
          ForgeConfigurationScope(
            values: values,
            style: style,
            child: const ForgeConfigurationTile(section: editingSection),
          ),
        ]),
      );
      expect(find.text('Editing'), findsNothing);
      expect(find.text('Wrap long lines'), findsOneWidget);
      final padding = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ForgeConfigurationTile),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(20));
      expect(ForgeConfigurationTileStyle.compact.dense, isTrue);
      expect(style, style.copyWith());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(_settle);
      values.dispose();
    });
  });
}

/// A kind `tom_forge_core` does not define: a number of stars.
class _RatingSetting extends ForgeSetting<int> {
  const _RatingSetting({
    required super.id,
    required super.storage,
    required super.label,
    required super.defaultValue,
  });

  @override
  String get kind => 'rating';

  @override
  int? decode(Object? stored) => stored is int ? stored : null;
}

// Configuration descriptions: a module contributes them as an extra, the kit
// collects them from every registered module, and the values service keeps
// their values through the state-store port.

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

const _wrap = ForgeBoolSetting(
  id: 'wrap',
  storage: ForgeSettingStorage('demo.wrap'),
  label: ForgeText('demo.wrap', 'Wrap'),
  defaultValue: true,
);

const _size = ForgeIntSetting(
  id: 'size',
  storage: ForgeSettingStorage('demo.size'),
  label: ForgeText('demo.size', 'Size'),
  defaultValue: 10,
  min: 1,
  max: 50,
  enabledWhen: ForgeSettingCondition.isTrue('wrap'),
);

const _fontSize = ForgeDoubleSetting(
  id: 'fontSize',
  storage: ForgeSettingStorage('demo.textSettings', path: ['dart', 'fontSize']),
  label: ForgeText('demo.fontSize', 'Font size'),
  defaultValue: 14,
  min: 6,
);

const _fontFamily = ForgeStringSetting(
  id: 'fontFamily',
  storage: ForgeSettingStorage(
    'demo.textSettings',
    path: ['dart', 'fontFamily'],
  ),
  label: ForgeText('demo.fontFamily', 'Font'),
  defaultValue: 'monospace',
  allowEmpty: false,
  visibleWhen: ForgeSettingCondition.equals('size', 20),
);

const _demo = ForgeConfigurationDescription(
  id: 'demo',
  title: ForgeText('demo', 'Demo'),
  sections: [
    ForgeSettingsSection(
      id: 'main',
      title: ForgeText('demo.main', 'Main'),
      settings: [_wrap, _size, _fontSize, _fontFamily],
    ),
  ],
);

class _Host implements ForgeEditorHost {
  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {}

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

class _DescribingModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  _DescribingModule(this.name, this.descriptions);

  final String name;
  final List<ForgeConfigurationDescription> descriptions;

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
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => [
    ForgeConfigurationDescriptionsExtra(descriptions),
  ];
}

class _OtherModule extends _DescribingModule {
  _OtherModule(super.name, super.descriptions);
}

void main() {
  group('collecting the descriptions', () {
    test('every registered module\'s descriptions, first id wins', () {
      final api = DefaultKitApi(
        editorHost: _Host(),
        fileSystem: TomMemoryFileSystem(),
        stateStore: ForgeMemoryStateStore(),
      );
      addTearDown(api.dispose);
      expect(forgeConfigurationDescriptionsOf(api), isEmpty);

      const other = ForgeConfigurationDescription(
        id: 'other',
        title: ForgeText('other', 'Other'),
        sections: [],
      );
      api.registerModule(_DescribingModule('a', [_demo]));
      api.registerModule(_OtherModule('b', [other, _demo]));

      final contributed = forgeConfigurationDescriptions(api.modules);
      expect(contributed.map((c) => c.description.id), ['demo', 'other']);
      expect(contributed.first.module.displayName, 'a');
      expect(forgeConfigurationDescriptionsOf(api), [_demo, other]);
    });
  });

  group('ForgeConfigurationValues', () {
    late ForgeMemoryStateStore store;
    late ForgeConfigurationValues values;
    final problems = <ForgeSettingProblem>[];

    setUp(() {
      problems.clear();
      store = ForgeMemoryStateStore();
      values = ForgeConfigurationValues(
        store,
        descriptions: [_demo],
        onProblem: problems.add,
      );
    });

    tearDown(() => values.dispose());

    test('defaults while nothing is stored', () async {
      await values.load();
      expect(values.valueOf(_wrap), isTrue);
      expect(values.valueOf(_size), 10);
      expect(values.valueOf(_fontSize), 14.0);
      expect(values.isStored(_size), isFalse);
      expect(problems, isEmpty);
    });

    test('set validates, writes through the store, reads back', () async {
      await values.load();
      expect(await values.set(_size, 99), ForgeConfigurationTexts.max(50));
      expect(await values.set(_size, 'x'), ForgeConfigurationTexts.wrongType);
      expect(store.writes, isEmpty);

      expect(await values.set(_size, 20), isNull);
      await values.flushed();
      expect(store.snapshot()['demo.size'], 20);
      expect(values.valueOf(_size), 20);
      expect(values.isStored(_size), isTrue);

      final again = ForgeConfigurationValues(store, descriptions: [_demo]);
      addTearDown(again.dispose);
      await again.load();
      expect(again.valueOf(_size), 20);
    });

    test('settings with a path share their key\'s document', () async {
      final seeded = ForgeMemoryStateStore(
        initial: {
          'demo.textSettings': {
            'yaml': {'fontSize': 12},
            'dart': {'tabSize': 4},
          },
        },
      );
      final shared = ForgeConfigurationValues(seeded, descriptions: [_demo]);
      addTearDown(shared.dispose);
      await shared.load();

      // One gesture: both set in the same microtask.
      await Future.wait([
        shared.set(_fontSize, 16),
        shared.set(_fontFamily, 'Fira Code'),
      ]);
      await shared.flushed();
      // One gesture, one write of the document; the other entries kept.
      expect(seeded.writes, hasLength(1));
      expect(seeded.snapshot()['demo.textSettings'], {
        'yaml': {'fontSize': 12},
        'dart': {'tabSize': 4, 'fontSize': 16.0, 'fontFamily': 'Fira Code'},
      });

      await shared.reset(_fontSize);
      await shared.flushed();
      expect(seeded.snapshot()['demo.textSettings'], {
        'yaml': {'fontSize': 12},
        'dart': {'tabSize': 4, 'fontFamily': 'Fira Code'},
      });
      expect(shared.valueOf(_fontSize), 14.0);
    });

    test('a document stored as JSON text is read at a path', () async {
      final seeded = ForgeMemoryStateStore(
        initial: {'demo.textSettings': '{"dart":{"fontSize":18}}'},
      );
      final shared = ForgeConfigurationValues(seeded, descriptions: [_demo]);
      addTearDown(shared.dispose);
      await shared.load();
      expect(shared.valueOf(_fontSize), 18.0);
    });

    test('an invalid stored value: default in effect, reported', () async {
      final seeded = ForgeMemoryStateStore(
        initial: {'demo.size': 500, 'demo.wrap': 'yes'},
      );
      final checked = ForgeConfigurationValues(
        seeded,
        descriptions: [_demo],
        onProblem: problems.add,
      );
      addTearDown(checked.dispose);
      await checked.load();
      expect(checked.valueOf(_size), 10);
      expect(checked.valueOf(_wrap), isTrue);
      expect(
        problems.map((p) => p.setting.id),
        unorderedEquals(['size', 'wrap']),
      );
      expect(
        checked.problems.firstWhere((p) => p.setting.id == 'size').message,
        ForgeConfigurationTexts.max(50),
      );
      // Writing a valid value clears the problem.
      await checked.set(_size, 5);
      expect(checked.problems.map((p) => p.setting.id), ['wrap']);
    });

    test('reset removes the stored value', () async {
      await values.load();
      await values.set(_wrap, false);
      await values.flushed();
      expect(store.snapshot()['demo.wrap'], false);
      await values.reset(_wrap);
      await values.flushed();
      expect(store.snapshot().containsKey('demo.wrap'), isFalse);
      expect(values.valueOf(_wrap), isTrue);
    });

    test('listenable, changes and the notifier follow every change', () async {
      await values.load();
      final listenable = values.listenable(_size);
      final seen = <int>[];
      listenable.addListener(() => seen.add(listenable.value));
      final changes = <ForgeSettingChange>[];
      final subscription = values.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      var notified = 0;
      values.addListener(() => notified++);

      await values.set(_size, 30);
      await values.set(_size, 30);
      await values.reset(_size);
      await pumpEventQueue();

      expect(seen, [30, 10]);
      expect(changes.map((c) => (c.value, c.previous)), [(30, 10), (10, 30)]);
      expect(notified, 2);
    });

    test('reload reads a key someone else changed', () async {
      await values.load();
      final listenable = values.listenable(_size);
      await store.write('demo.size', 42);
      expect(values.valueOf(_size), 10);
      await values.reload(keys: ['demo.size']);
      expect(values.valueOf(_size), 42);
      expect(listenable.value, 42);
    });

    test('a value set before load is not written; the restore wins', () async {
      await store.write('demo.size', 7);
      store.writes.clear();
      await values.set(_size, 30);
      expect(values.valueOf(_size), 30);
      await values.flushed();
      expect(store.writes, isEmpty);
      await values.load();
      expect(values.valueOf(_size), 7);
    });

    test('conditions: visibleWhen and enabledWhen', () async {
      await values.load();
      expect(values.isEnabled(_size), isTrue);
      await values.set(_wrap, false);
      expect(values.isEnabled(_size), isFalse);
      expect(values.isVisible(_fontFamily), isFalse);
      await values.set(_size, 20);
      expect(values.isVisible(_fontFamily), isTrue);
      expect(values.isVisible(_wrap), isTrue);
    });

    test('a description added after load is read at once', () async {
      await values.load();
      const extra = ForgeIntSetting(
        id: 'late',
        storage: ForgeSettingStorage('demo.late'),
        label: ForgeText('demo.late', 'Late'),
        defaultValue: 1,
      );
      await store.write('demo.late', 3);
      await values.addDescription(
        const ForgeConfigurationDescription(
          id: 'late',
          title: ForgeText('late', 'Late'),
          sections: [
            ForgeSettingsSection(
              id: 's',
              title: ForgeText('s', 'S'),
              settings: [extra],
            ),
          ],
        ),
      );
      expect(values.valueOf(extra), 3);
      expect(values.descriptions.map((d) => d.id), ['demo', 'late']);
      expect(values.descriptionOf(extra)!.id, 'late');
    });
  });
}

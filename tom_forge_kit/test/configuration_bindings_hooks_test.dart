// The values service with storage bindings (an application's own place for
// settings), companion settings, settings without a value, and the hooks a
// setting names (actions, flows, detectors, choices, status, catalogues).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

const _label = ForgeText('x', 'X');

const _wrap = ForgeBoolSetting(
  id: 'wrap',
  storage: ForgeSettingStorage('editor', path: ['md', 'wrap'], binding: 'yaml'),
  label: _label,
  defaultValue: true,
);

const _tab = ForgeIntSetting(
  id: 'tab',
  storage: ForgeSettingStorage('editor', path: ['md', 'tab'], binding: 'yaml'),
  label: _label,
  defaultValue: 2,
  min: 1,
);

const _theme = ForgeChoiceSetting(
  id: 'theme',
  storage: ForgeSettingStorage('forge.appearance.themeMode'),
  label: _label,
  defaultValue: 'system',
  choices: [
    ForgeSettingChoice('system', _label),
    ForgeSettingChoice('dark', _label),
  ],
);

const _deleted = ForgeStringListSetting(
  id: 'deletedBindings',
  storage: ForgeSettingStorage('forge.shortcuts.deletedBindings'),
  label: _label,
  defaultValue: [],
);

const _shortcuts = ForgeKeyBindingTableSetting(
  id: 'shortcuts',
  storage: ForgeSettingStorage('forge.shortcuts.overrides'),
  label: _label,
  catalogue: 'actions',
  deletedBindings: _deleted,
  actions: ['resetShortcuts'],
);

const _pandoc = ForgeToolPathSetting(
  id: 'pandoc',
  storage: ForgeSettingStorage('forge.tools.pandoc.path'),
  label: _label,
  detector: 'detect',
  hints: ForgeDetectionHints(executableNames: ['pandoc']),
  actions: ['download', 'broken', 'refused'],
);

const _editor = ForgeChoiceSetting(
  id: 'editor',
  storage: ForgeSettingStorage('editor.default'),
  label: _label,
  defaultValue: '',
  allowNone: true,
  choices: [ForgeSettingChoice('text', _label)],
  choicesProvider: 'editors',
);

const _font = ForgeFontFamilySetting(
  id: 'font',
  storage: ForgeSettingStorage('font'),
  label: _label,
  monospace: true,
  suggestions: ['JetBrains Mono'],
);

const _issues = ForgeStatusSetting(
  id: 'issues',
  label: _label,
  status: 'issues',
);

const _signIn = ForgeActionSetting(id: 'signIn', label: _label, flow: 'otp');

const _token = ForgeStringSetting(
  id: 'token',
  storage: ForgeSettingStorage('token'),
  label: _label,
  defaultValue: '',
  actions: ['otp'],
);

const _description = ForgeConfigurationDescription(
  id: 'demo',
  title: _label,
  sections: [
    ForgeSettingsSection(
      id: 'main',
      title: _label,
      settings: [
        _theme,
        ForgeSettingsGroup(id: 'md', title: _label, settings: [_wrap, _tab]),
        _shortcuts,
        _pandoc,
        _editor,
        _font,
        _issues,
        _signIn,
        _token,
      ],
    ),
  ],
);

ForgeSettingHooks _hooks() => ForgeSettingHooks(
  actions: [
    ForgeCallbackAction(
      id: 'resetShortcuts',
      label: _label,
      confirmation: const ForgeText('confirm', 'Reset every shortcut?'),
      onRun: (_) async => const ForgeActionResult.success(refresh: true),
    ),
    ForgeCallbackAction(
      id: 'download',
      label: _label,
      onRun: (context) async {
        context.progress(fraction: 0.5);
        return const ForgeActionResult.success(value: '/opt/pandoc/bin/pandoc');
      },
    ),
    ForgeCallbackAction(
      id: 'broken',
      label: _label,
      onRun: (_) async => throw StateError('no network'),
    ),
    ForgeCallbackAction(
      id: 'refused',
      label: _label,
      onRun: (_) async => const ForgeActionResult.success(value: 'a\nb'),
    ),
  ],
  detectors: [
    ForgeCallbackDetector(
      id: 'detect',
      onCheck: (context, value, hints) async => ForgeDetectedCandidate(
        value: value.isEmpty ? '/usr/bin/${hints.executableNames.last}' : value,
        level: value.contains('old')
            ? ForgeStatusLevel.warning
            : ForgeStatusLevel.ok,
        source: hints.searchRoots.join(','),
      ),
      onDetect: (context, hints) async => [
        for (final name in hints.executableNames)
          ForgeDetectedCandidate(
            value: '/usr/bin/$name',
            level: ForgeStatusLevel.ok,
          ),
      ],
    ),
  ],
  choices: [
    ForgeCallbackChoicesProvider(
      id: 'editors',
      onChoices: (context) async => [
        const ForgeSettingChoice('text', ForgeText.literal('Text again')),
        const ForgeSettingChoice('markdown', ForgeText.literal('Markdown')),
      ],
    ),
    ForgeCallbackChoicesProvider(
      id: ForgeFontFamilySetting.systemFonts,
      onChoices: (context) async => [
        ForgeSettingChoice(
          context.key == 'monospace' ? 'Menlo' : 'Helvetica',
          const ForgeText.literal('font'),
        ),
        const ForgeSettingChoice('monospace', ForgeText.literal('mono')),
      ],
    ),
  ],
  statuses: [
    ForgeCallbackStatusProvider(
      id: 'issues',
      onCurrent: (context) async => ForgeStatusInfo(
        level: ForgeStatusLevel.warning,
        detail: '${context.valueOf('theme')}',
      ),
      onWatch: (_) => Stream.fromIterable(const [
        ForgeStatusInfo(level: ForgeStatusLevel.busy),
        ForgeStatusInfo(level: ForgeStatusLevel.ok),
      ]),
    ),
  ],
  catalogues: [
    ForgeCallbackActionCatalogue(
      id: 'actions',
      onActions: (_) async => const [
        ForgeCatalogueAction(
          id: 'md.bold',
          label: 'Bold',
          defaultBinding: ForgeKeyChord([
            ForgeKeyStroke(0x62, primaryModifier: true),
          ]),
        ),
        ForgeCatalogueAction(id: 'md.italic', label: 'Italic'),
      ],
    ),
  ],
  flows: [_OtpFlow()],
);

void main() {
  group('bindings', () {
    late ForgeMemoryStateStore store;
    late ForgeMemorySettingBinding yaml;
    late ForgeConfigurationValues values;

    setUp(() {
      store = ForgeMemoryStateStore();
      yaml = ForgeMemorySettingBinding(
        'yaml',
        initial: {
          'editor': {
            'md': {'tab': 4},
            'dart': {'tab': 2},
          },
        },
      );
      values = ForgeConfigurationValues(
        store,
        descriptions: [_description],
        bindings: [yaml],
      );
    });

    tearDown(() async {
      values.dispose();
      await yaml.close();
    });

    test('read from the binding at load, state store left alone', () async {
      await values.load();
      expect(values.valueOf(_tab), 4);
      expect(values.isStored(_tab), isTrue);
      expect(values.valueOf(_wrap), isTrue);
      expect(values.bindings.keys, ['yaml']);
      expect(store.snapshot(), isEmpty);
    });

    test('writes go to the binding, coalesced per gesture', () async {
      await values.load();
      await Future.wait([values.set(_tab, 8), values.set(_wrap, false)]);
      await values.flushed();
      expect(yaml.snapshot()['editor'], {
        'md': {'tab': 8, 'wrap': false},
        'dart': {'tab': 2},
      });
      expect(store.writes, isEmpty);
      await values.reset(_tab);
      await values.flushed();
      expect(yaml.snapshot()['editor'], {
        'md': {'wrap': false},
        'dart': {'tab': 2},
      });
    });

    test('nothing reaches the binding before load', () async {
      await values.set(_tab, 9);
      await values.flushed();
      expect((yaml.snapshot()['editor'] as Map)['md'], {'tab': 4});
      await values.load();
      expect(values.valueOf(_tab), 4);
    });

    test('a change the binding reports is read again', () async {
      await values.load();
      final changes = <ForgeSettingChange>[];
      final subscription = values.changes.listen(changes.add);
      addTearDown(subscription.cancel);
      yaml.change('editor', {
        'md': {'tab': 6},
      });
      await pumpEventQueue();
      expect(values.valueOf(_tab), 6);
      expect(changes.single.setting, _tab);
    });

    test('state-store settings behave as before', () async {
      await values.load();
      expect(await values.set(_theme, 'dark'), isNull);
      await values.flushed();
      expect(store.snapshot()['forge.appearance.themeMode'], 'dark');
      await values.reload(keys: ['forge.appearance.themeMode']);
      expect(values.valueOf(_theme), 'dark');
    });

    test('a missing binding: default, writes refused; added later', () async {
      final unbound = ForgeConfigurationValues(
        store,
        descriptions: [_description],
      );
      addTearDown(unbound.dispose);
      await unbound.load();
      expect(unbound.valueOf(_tab), 2);
      expect(
        unbound.storageProblem(_tab),
        ForgeConfigurationTexts.noBinding('yaml'),
      );
      expect(
        await unbound.set(_tab, 5),
        ForgeConfigurationTexts.noBinding('yaml'),
      );
      await unbound.addBinding(yaml);
      expect(unbound.valueOf(_tab), 4);
      expect(await unbound.set(_tab, 5), isNull);
      await unbound.flushed();
      expect(((yaml.snapshot()['editor'] as Map)['md'] as Map)['tab'], 5);
    });

    test('a callback binding over an application\'s own document', () async {
      final file = <String, Object?>{
        'editor': jsonEncode({
          'md': {'wrap': false},
        }),
      };
      final callback = ForgeCallbackSettingBinding(
        id: 'yaml',
        onRead: (key) => file[key],
        onWrite: (key, document) => file[key] = document,
      );
      final bound = ForgeConfigurationValues(
        store,
        descriptions: [_description],
        bindings: [callback],
      );
      addTearDown(bound.dispose);
      await bound.load();
      expect(bound.valueOf(_wrap), isFalse);
      await bound.set(_tab, 3);
      await bound.flushed();
      expect(file['editor'], {
        'md': {'wrap': false, 'tab': 3},
      });
    });
  });

  group('companions and settings without a value', () {
    test('the deleted bindings are kept; reset clears both', () async {
      final store = ForgeMemoryStateStore(
        initial: {
          'forge.shortcuts.overrides': jsonEncode({
            'md.italic': {
              'keyId': 0x69,
              'primaryModifier': true,
              'control': false,
              'shift': false,
              'alt': false,
            },
          }),
          'forge.shortcuts.deletedBindings': jsonEncode(['md.bold']),
        },
      );
      final values = ForgeConfigurationValues(
        store,
        descriptions: [_description],
        hooks: _hooks(),
      );
      addTearDown(values.dispose);
      await values.load();
      expect(values.valueOf(_deleted), ['md.bold']);
      expect(values.registered(_deleted), _deleted);
      final rows = await values.keyBindingRows(_shortcuts);
      expect(rows.map((r) => (r.action.id, r.deleted, r.overridden)), [
        ('md.bold', true, false),
        ('md.italic', false, true),
      ]);

      await values.reset(_shortcuts);
      await values.flushed();
      expect(
        store.snapshot().containsKey('forge.shortcuts.overrides'),
        isFalse,
      );
      expect(
        store.snapshot().containsKey('forge.shortcuts.deletedBindings'),
        isFalse,
      );
    });

    test('actions and status lines keep nothing', () async {
      final store = ForgeMemoryStateStore();
      final values = ForgeConfigurationValues(
        store,
        descriptions: [_description],
      );
      addTearDown(values.dispose);
      await values.load();
      expect(values.registered(_issues), isNull);
      expect(values.descriptionOf(_issues), _description);
      expect(values.valueOf(_issues), ForgeNoValue.instance);
      expect(await values.set(_signIn, 'x'), isNull);
      await values.flushed();
      expect(store.writes, isEmpty);
    });
  });

  group('hooks', () {
    late ForgeMemoryStateStore store;
    late ForgeConfigurationValues values;

    setUp(() async {
      store = ForgeMemoryStateStore();
      values = ForgeConfigurationValues(
        store,
        descriptions: [_description],
        hooks: _hooks(),
      );
      await values.load();
    });

    tearDown(() => values.dispose());

    test('an action runs, reports progress, its value is written', () async {
      final progress = <double?>[];
      final result = await values.runAction(
        _pandoc,
        'download',
        onProgress: (p) => progress.add(p.fraction),
      );
      expect(result.succeeded, isTrue);
      expect(progress, [0.5]);
      expect(values.valueOf(_pandoc), '/opt/pandoc/bin/pandoc');
      await values.flushed();
      expect(
        store.snapshot()['forge.tools.pandoc.path'],
        '/opt/pandoc/bin/pandoc',
      );
    });

    test('a missing, throwing or refused action is a failure', () async {
      final missing = await values.runAction(_pandoc, 'nope');
      expect(missing.outcome, ForgeActionOutcome.failure);
      expect(missing.message, ForgeConfigurationTexts.hookMissing('nope'));
      final broken = await values.runAction(_pandoc, 'broken');
      expect(broken.outcome, ForgeActionOutcome.failure);
      expect(broken.message!.resolve(), contains('no network'));
      final refused = await values.runAction(_pandoc, 'refused');
      expect(refused.message, ForgeConfigurationTexts.multiline);
      expect(values.valueOf(_pandoc), '');
    });

    test('tool path: check and detect with the hints merged', () async {
      final empty = await values.checkToolPath(_pandoc);
      expect(empty.value, '/usr/bin/pandoc');
      await values.set(_pandoc, '/old/pandoc');
      final set = await values.checkToolPath(
        _pandoc,
        hints: const ForgeDetectionHints(searchRoots: ['/opt']),
      );
      expect(set.level, ForgeStatusLevel.warning);
      expect(set.source, '/opt');
      final all = await values.detectToolPath(
        _pandoc,
        hints: const ForgeDetectionHints(executableNames: ['pandoc-3']),
      );
      expect(all.map((c) => c.value), ['/usr/bin/pandoc', '/usr/bin/pandoc-3']);

      final bare = ForgeConfigurationValues(
        store,
        descriptions: [_description],
      );
      addTearDown(bare.dispose);
      final missing = await bare.checkToolPath(_pandoc);
      expect(missing.isMissing, isTrue);
      expect(missing.message, ForgeConfigurationTexts.hookMissing('detect'));
      expect(await bare.detectToolPath(_pandoc), isEmpty);
    });

    test('choices: fixed first, provided after, each value once', () async {
      final editors = await values.choicesFor(_editor);
      expect(editors.map((c) => c.value), ['text', 'markdown']);
      final fonts = await values.choicesFor(_font);
      expect(fonts.map((c) => c.value), [
        'JetBrains Mono',
        'Menlo',
        'monospace',
        'sans-serif',
        'serif',
      ]);
      expect(await values.choicesFor(_theme), _theme.choices);
      expect(await values.choicesFor(_wrap), isEmpty);
    });

    test('status: read now, followed as it changes', () async {
      await values.set(_theme, 'dark');
      final status = await values.statusOf(_issues);
      expect(status.level, ForgeStatusLevel.warning);
      expect(status.detail, 'dark');
      final stream = values.watchStatus(_issues)!;
      expect(await stream.map((s) => s.level).toList(), [
        ForgeStatusLevel.busy,
        ForgeStatusLevel.ok,
      ]);
      final bare = ForgeConfigurationValues(
        store,
        descriptions: [_description],
      );
      addTearDown(bare.dispose);
      expect((await bare.statusOf(_issues)).level, ForgeStatusLevel.unknown);
      expect(bare.watchStatus(_issues), isNull);
    });

    test('a flow\'s done value is written for the setting', () async {
      expect(values.startFlow(_token, 'none'), isNull);
      final session = values.startFlow(_token, 'otp')!;
      final first = await session.start();
      expect(first.kind, ForgeFlowStepKind.input);
      final done = await session.respond(
        const ForgeFlowResponse(values: {'code': '424242'}),
      );
      expect(done.kind, ForgeFlowStepKind.done);
      expect(done.result!.succeeded, isTrue);
      expect(values.valueOf(_token), 'token-424242');
    });

    test('the trail records hook runs and binding changes', () async {
      final lines = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      kConfigurationValuesDebug = true;
      addTearDown(() {
        debugPrint = previousPrint;
        kConfigurationValuesDebug = false;
      });
      await values.runAction(_pandoc, 'download');
      final yaml = ForgeMemorySettingBinding('yaml');
      addTearDown(yaml.close);
      await values.addBinding(yaml);
      yaml.change('editor', {
        'md': {'tab': 3},
      });
      await pumpEventQueue();
      expect(values.valueOf(_tab), 3);
      expect(
        lines,
        contains(
          matches(
            r'^\[CV \d\d:\d\d:\d\d\.\d{3}\] action download for pandoc: run$',
          ),
        ),
      );
      expect(lines, contains(contains('binding yaml changed editor')));
    });
  });

  test('modules contribute hooks; later modules replace an id', () {
    final api = DefaultKitApi(
      editorHost: _Host(),
      fileSystem: TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
    addTearDown(api.dispose);
    expect(forgeConfigurationHooksOf(api).ids, isEmpty);
    api.registerModule(_HookModule('a', _hooks()));
    // The registry keeps one module per type: the second is another type.
    api.registerModule(
      _OtherHookModule(
        'b',
        ForgeSettingHooks(
          actions: [
            ForgeCallbackAction(
              id: 'download',
              label: const ForgeText('b', 'B'),
              onRun: (_) async => const ForgeActionResult.cancelled(),
            ),
          ],
        ),
      ),
    );
    final hooks = forgeConfigurationHooksOf(api);
    expect(hooks.action('download')!.label.key, 'b');
    expect(hooks.detector('detect'), isNotNull);
    expect(_description.problems(hooks: hooks), isEmpty);
  });
}

class _OtpFlow extends ForgeSettingFlow {
  @override
  String get id => 'otp';

  @override
  ForgeText get label => _label;

  @override
  ForgeFlowSession start(ForgeSettingContext context) => _OtpSession();
}

class _OtpSession implements ForgeFlowSession {
  @override
  Future<ForgeFlowStep> start() async => const ForgeFlowStep.input(
    fields: [
      ForgeFlowField(
        id: 'code',
        label: _label,
        kind: ForgeFlowFieldKind.oneTimeCode,
      ),
    ],
  );

  @override
  Future<ForgeFlowStep> respond(ForgeFlowResponse response) async =>
      ForgeFlowStep.done(
        ForgeActionResult.success(value: 'token-${response.values['code']}'),
      );

  @override
  Future<ForgeFlowStep> poll() => start();

  @override
  void cancel() {}
}

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

class _HookModule extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _HookModule(this.name, this.hooks);

  final String name;
  final ForgeSettingHooks hooks;

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
  List<ForgeModuleExtra> get ownExtras => [ForgeConfigurationHooksExtra(hooks)];
}

class _OtherHookModule extends _HookModule {
  _OtherHookModule(super.name, super.hooks);
}

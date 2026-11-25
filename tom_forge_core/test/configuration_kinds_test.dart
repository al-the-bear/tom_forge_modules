// The setting kinds that carry behaviour (font family, key bindings, tool
// paths, actions, status lines, dates and times), the hook contract, the
// storage bindings and sub-groups — and the stored formats Forge already
// keeps (`forge.shortcuts.*`, `forge.files.typeDefaults`,
// `forge.tools.<id>.path`), read and written alike.

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

const _label = ForgeText('x', 'X');

// Flutter's LogicalKeyboardKey ids: keyB, keyK, keyC, enter.
const _keyB = 0x62;
const _keyK = 0x6b;
const _keyC = 0x63;
const _enter = 0x10000000d;

const _primaryB = ForgeKeyStroke(_keyB, primaryModifier: true);
const _primaryK = ForgeKeyStroke(_keyK, primaryModifier: true);
const _controlB = ForgeKeyStroke(_keyB, control: true);

Map<String, Object?> _stroke(
  int keyId, {
  bool primary = false,
  bool control = false,
  bool shift = false,
  bool alt = false,
}) => {
  'keyId': keyId,
  'primaryModifier': primary,
  'control': control,
  'shift': shift,
  'alt': alt,
};

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
  catalogue: 'forge.actions',
  deletedBindings: _deleted,
  wildcardPrefixes: ['md', 'dart'],
);

const _chordTable = ForgeKeyBindingTableSetting(
  id: 'chords',
  storage: ForgeSettingStorage('forge.shortcuts.chordOverrides'),
  label: _label,
  catalogue: 'forge.actions',
  chords: true,
);

const _typeDefaults = ForgeStringMapSetting(
  id: 'typeDefaults',
  storage: ForgeSettingStorage('forge.files.typeDefaults'),
  label: _label,
  defaultValue: {'.md': 'markdown', '.dart': 'code'},
  keyNormalizer: ForgeMapKeyNormalizer.fileExtension,
  mergeDefaults: true,
  defaultKey: '*',
  valueChoicesProvider: 'forge.editorsForType',
);

const _pandoc = ForgeToolPathSetting(
  id: 'pandoc',
  storage: ForgeSettingStorage('forge.tools.pandoc.path'),
  label: _label,
  detector: 'forge.tools.detect',
  hints: ForgeDetectionHints(
    executableNames: ['pandoc'],
    candidatePaths: ['/opt/homebrew/bin/pandoc'],
  ),
  actions: ['forge.tools.download'],
);

void main() {
  group('sub-groups', () {
    const grouped = ForgeConfigurationDescription(
      id: 'md',
      title: _label,
      sections: [
        ForgeSettingsSection(
          id: 'editor',
          title: _label,
          settings: [
            ForgeBoolSetting(
              id: 'wrap',
              storage: ForgeSettingStorage('md.wrap'),
              label: _label,
              defaultValue: true,
            ),
            ForgeSettingsGroup(
              id: 'headings',
              title: ForgeText('md.headings', 'Headings'),
              settings: [
                ForgeIntSetting(
                  id: 'h1Size',
                  storage: ForgeSettingStorage('md.h1'),
                  label: _label,
                  defaultValue: 24,
                  enabledWhen: ForgeSettingCondition.isTrue('wrap'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    test('entries keep the groups, settings flatten them', () {
      final section = grouped.sections.single;
      expect(section.entries, hasLength(2));
      expect(section.groups.single.id, 'headings');
      expect(section.settings.map((s) => s.id), ['wrap', 'h1Size']);
      expect(grouped.settingById('h1Size'), isNotNull);
      expect(grouped.problems(), isEmpty);
    });

    test('a group id twice and a condition on a group are problems', () {
      const broken = ForgeConfigurationDescription(
        id: 'b',
        title: _label,
        sections: [
          ForgeSettingsSection(
            id: 's',
            title: _label,
            settings: [
              ForgeSettingsGroup(id: 'g', title: _label, settings: []),
              ForgeSettingsGroup(
                id: 'g',
                title: _label,
                settings: [
                  ForgeBoolSetting(
                    id: 'a',
                    storage: ForgeSettingStorage('b.a'),
                    label: _label,
                    defaultValue: true,
                    visibleWhen: ForgeSettingCondition.isTrue('g'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final problems = broken.problems();
      expect(problems, contains(contains('group id "g" twice')));
      expect(problems, contains(contains('condition on "g"')));
    });
  });

  group('hooks', () {
    ForgeSettingHooks registry() => ForgeSettingHooks(
      actions: [
        ForgeCallbackAction(
          id: 'forge.tools.download',
          label: _label,
          onRun: (context) async =>
              const ForgeActionResult.success(value: '/opt/pandoc'),
        ),
      ],
      detectors: [
        ForgeCallbackDetector(
          id: 'forge.tools.detect',
          onCheck: (context, value, hints) async => ForgeDetectedCandidate(
            value: value.isEmpty ? hints.candidatePaths.first : value,
            level: ForgeStatusLevel.ok,
            version: '3.1',
          ),
          onDetect: (context, hints) async => [
            for (final path in hints.candidatePaths)
              ForgeDetectedCandidate(value: path, level: ForgeStatusLevel.ok),
          ],
        ),
      ],
    );

    test('the registry finds hooks by id; later ids replace earlier', () {
      final hooks = registry();
      expect(hooks.has('forge.tools.download'), isTrue);
      expect(hooks.detector('forge.tools.detect'), isNotNull);
      expect(hooks.action('forge.tools.detect'), isNull);
      expect(hooks.ids, {'forge.tools.download', 'forge.tools.detect'});

      final replacing = ForgeSettingHooks(
        actions: [
          ForgeCallbackAction(
            id: 'forge.tools.download',
            label: const ForgeText('other', 'Other'),
            onRun: (_) async => const ForgeActionResult.cancelled(),
          ),
        ],
      );
      final merged = ForgeSettingHooks.merged([hooks, replacing]);
      expect(merged.action('forge.tools.download')!.label.key, 'other');
      expect(merged.has('forge.tools.detect'), isTrue);
    });

    test('problems with a registry name the missing hooks', () {
      const described = ForgeConfigurationDescription(
        id: 'tools',
        title: _label,
        sections: [
          ForgeSettingsSection(id: 's', title: _label, settings: [_pandoc]),
        ],
      );
      expect(_pandoc.hookIds, ['forge.tools.download', 'forge.tools.detect']);
      expect(described.problems(hooks: registry()), isEmpty);
      expect(
        described.problems(hooks: ForgeSettingHooks()),
        contains(contains('names the hook "forge.tools.detect"')),
      );
    });

    test('an action and a detector run with a context', () async {
      final hooks = registry();
      final context = ForgeSettingContext(
        setting: _pandoc,
        value: '',
        hooks: hooks,
        readSetting: (id) => id == 'other' ? 7 : null,
      );
      final result = await hooks.action('forge.tools.download')!.run(context);
      expect(result.succeeded, isTrue);
      expect(result.hasValue, isTrue);
      expect(result.value, '/opt/pandoc');
      expect(context.valueOf('other'), 7);
      expect(context.about('row').key, 'row');

      final detector = hooks.detector('forge.tools.detect')!;
      final checked = await detector.check(context, '', _pandoc.hints);
      expect(checked.value, '/opt/homebrew/bin/pandoc');
      expect(checked.usable, isTrue);
      expect(await detector.detect(context, _pandoc.hints), hasLength(1));
    });

    test('detection hints merge; cancellation completes once', () async {
      const app = ForgeDetectionHints(
        searchRoots: ['/Applications'],
        environmentVariables: ['PANDOC_HOME'],
        searchPath: false,
        maxDepth: 3,
      );
      final merged = _pandoc.hints.merge(app);
      expect(merged.executableNames, ['pandoc']);
      expect(merged.searchRoots, ['/Applications']);
      expect(merged.environmentVariables, ['PANDOC_HOME']);
      expect(merged.searchPath, isTrue);
      expect(merged.maxDepth, 3);
      expect(const ForgeDetectionHints().isEmpty, isTrue);
      expect(const ForgeDetectedCandidate.missing().isMissing, isTrue);

      final cancellation = ForgeHookCancellation();
      expect(cancellation.isCancelled, isFalse);
      cancellation
        ..cancel()
        ..cancel();
      await cancellation.whenCancelled;
      expect(cancellation.isCancelled, isTrue);
    });

    test('a flow session is driven step by step', () async {
      final flow = _FakeFlow();
      final session = flow.start(
        ForgeSettingContext(
          setting: _pandoc,
          value: '',
          hooks: ForgeSettingHooks(flows: [flow]),
        ),
      );
      final first = await session.start();
      expect(first.kind, ForgeFlowStepKind.input);
      expect(first.fields.single.kind, ForgeFlowFieldKind.oneTimeCode);
      final wrong = await session.respond(
        const ForgeFlowResponse(values: {'code': '000000'}),
      );
      expect(wrong.error, isNotNull);
      final waiting = await session.respond(
        const ForgeFlowResponse(values: {'code': '123456'}),
      );
      expect(waiting.kind, ForgeFlowStepKind.waiting);
      final done = await session.poll();
      expect(done.kind, ForgeFlowStepKind.done);
      expect(done.result!.value, 'token-123456');
    });

    test('status and choices providers answer data', () async {
      final status = ForgeCallbackStatusProvider(
        id: 'check',
        onCurrent: (_) async => const ForgeStatusInfo(
          level: ForgeStatusLevel.warning,
          items: [
            ForgeStatusItem(level: ForgeStatusLevel.error, text: 'a.yaml'),
          ],
        ),
        onWatch: (_) =>
            Stream.value(const ForgeStatusInfo(level: ForgeStatusLevel.ok)),
      );
      final context = ForgeSettingContext(
        setting: _pandoc,
        value: '',
        hooks: ForgeSettingHooks(statuses: [status]),
      );
      expect((await status.current(context)).items.single.text, 'a.yaml');
      expect((await status.watch(context)!.first).level, ForgeStatusLevel.ok);

      final choices = ForgeCallbackChoicesProvider(
        id: 'editors',
        onChoices: (context) async => [
          ForgeSettingChoice(context.key!, ForgeText.literal(context.key!)),
        ],
      );
      final answered = await choices.choices(context.about('.md'));
      expect(answered.single.value, '.md');
      expect(answered.single.label.resolve((_) => 'translated'), '.md');
    });
  });

  group('storage bindings', () {
    test('storage with a binding: location and document id', () {
      const storage = ForgeSettingStorage(
        'editor',
        path: ['md', 'wrap'],
        binding: 'yaml',
      );
      expect(storage.location, 'yaml:editor/md/wrap');
      expect(storage.documentId, 'yaml:editor');
      expect(
        storage,
        isNot(const ForgeSettingStorage('editor', path: ['md', 'wrap'])),
      );
      expect(const ForgeSettingStorage.none().stores, isFalse);
    });

    test('memory binding reads, writes and reports outside changes', () async {
      final binding = ForgeMemorySettingBinding('mem', initial: {'a': 1});
      addTearDown(binding.close);
      expect(await binding.read('a'), 1);
      await binding.write('b', {'x': true});
      await binding.write('a', null);
      expect(binding.snapshot(), {
        'b': {'x': true},
      });
      final seen = <String>[];
      final subscription = binding.watch().listen(seen.add);
      binding.change('c', 'v');
      await pumpEventQueue();
      await subscription.cancel();
      expect(seen, ['c']);
      expect(await binding.read('c'), 'v');
    });

    test('callback binding adapts functions', () async {
      final backing = <String, Object?>{};
      final changes = StreamController<String>.broadcast();
      addTearDown(changes.close);
      final binding = ForgeCallbackSettingBinding(
        id: 'cb',
        onRead: (key) => backing[key],
        onWrite: (key, document) => backing[key] = document,
        onWatch: () => changes.stream,
      );
      await binding.write('k', 3);
      expect(await binding.read('k'), 3);
      expect(binding.watch(), isNotNull);
      await binding.flushed();
    });

    test('two settings at one binding location are a problem', () {
      const a = ForgeBoolSetting(
        id: 'a',
        storage: ForgeSettingStorage('k', binding: 'yaml'),
        label: _label,
        defaultValue: true,
      );
      const b = ForgeBoolSetting(
        id: 'b',
        storage: ForgeSettingStorage('k', binding: 'yaml'),
        label: _label,
        defaultValue: true,
      );
      const c = ForgeBoolSetting(
        id: 'c',
        storage: ForgeSettingStorage('k'),
        label: _label,
        defaultValue: true,
      );
      const description = ForgeConfigurationDescription(
        id: 'd',
        title: _label,
        sections: [
          ForgeSettingsSection(id: 's', title: _label, settings: [a, b, c]),
        ],
      );
      expect(description.problems(), ['b and a are both stored at yaml:k']);
    });
  });

  group('numbers: scale and unit', () {
    test('int shown in another unit', () {
      const limit = ForgeIntSetting(
        id: 'limit',
        storage: ForgeSettingStorage('limit'),
        label: _label,
        defaultValue: 1048576,
        scale: 1048576,
        unit: ForgeText('mb', 'MB'),
        min: 1024,
      );
      expect(limit.toShown(5242880), 5);
      expect(limit.fromShown(2.5), 2621440);
      expect(limit.validate(limit.fromShown(0.0001)), isNotNull);
      const plain = ForgeIntSetting(
        id: 'p',
        storage: ForgeSettingStorage('p'),
        label: _label,
        defaultValue: 3,
      );
      expect(plain.toShown(3), 3);
    });

    test('double shown in another unit', () {
      const seconds = ForgeDoubleSetting(
        id: 's',
        storage: ForgeSettingStorage('s'),
        label: _label,
        defaultValue: 1500,
        scale: 1000,
        unit: ForgeText('s', 's'),
      );
      expect(seconds.toShown(1500), 1.5);
      expect(seconds.fromShown(2), 2000.0);
    });
  });

  group('choices from a provider', () {
    test('choice: provider allows any value, none when allowed', () {
      const fixed = ForgeChoiceSetting(
        id: 'theme',
        storage: ForgeSettingStorage('t'),
        label: _label,
        defaultValue: 'dark',
        choices: [ForgeSettingChoice('dark', _label)],
      );
      expect(fixed.validate('light'), ForgeConfigurationTexts.choice);
      expect(fixed.validate(''), ForgeConfigurationTexts.choice);
      const provided = ForgeChoiceSetting(
        id: 'editor',
        storage: ForgeSettingStorage('e'),
        label: _label,
        defaultValue: '',
        choicesProvider: 'editors',
        allowNone: true,
      );
      expect(provided.validate(''), isNull);
      expect(provided.validate('markdown'), isNull);
      expect(provided.validate('a\nb'), ForgeConfigurationTexts.multiline);
      expect(provided.hookIds, ['editors']);
    });
  });

  group('file type defaults (forge.files.typeDefaults)', () {
    test('reads the stored JSON text, keys normalised, laid over defaults', () {
      final stored = jsonEncode({
        'MD': 'preview',
        '.YAML': 'yaml',
        '.*': 'text',
      });
      final read = _typeDefaults.read(stored);
      expect(read.problem, isNull);
      expect(read.value, {
        '.md': 'preview',
        '.dart': 'code',
        '.yaml': 'yaml',
        '*': 'text',
      });
    });

    test('round trip: encode is the map Forge writes', () {
      const value = {'.md': 'markdown', '*': 'text'};
      final encoded = _typeDefaults.encode(value);
      expect(jsonDecode(jsonEncode(encoded)), value);
      expect(_typeDefaults.decode(jsonEncode(encoded)), value);
      expect(_typeDefaults.normalizeKey(' Md '), '.md');
      expect(_typeDefaults.normalizeKey('*'), '*');
    });

    test('nothing stored: the built-in defaults; values from a provider', () {
      expect(_typeDefaults.read(null).value, _typeDefaults.defaultValue);
      expect(_typeDefaults.validate({'.md': 'anyEditor'}), isNull);
      expect(_typeDefaults.hookIds, ['forge.editorsForType']);
    });
  });

  group('tool path (forge.tools.<id>.path)', () {
    test('stored as the trimmed path; empty not stored', () {
      expect(_pandoc.encode('  /usr/bin/pandoc '), '/usr/bin/pandoc');
      expect(_pandoc.encode(''), isNull);
      expect(_pandoc.decode(' /a '), '/a');
      expect(
        _pandoc.read('/usr/local/bin/pandoc').value,
        '/usr/local/bin/pandoc',
      );
      expect(_pandoc.read(null).value, '');
      expect(_pandoc.validate('a\nb'), ForgeConfigurationTexts.multiline);
      expect(_pandoc.kind, ForgeSettingKinds.toolPath);
    });
  });

  group('font family', () {
    test('a name; empty when allowed; the provider named', () {
      const font = ForgeFontFamilySetting(
        id: 'font',
        storage: ForgeSettingStorage('f'),
        label: _label,
        monospace: true,
      );
      expect(font.validate(''), isNull);
      expect(font.validate('Fira Code'), isNull);
      expect(font.validate('a\nb'), ForgeConfigurationTexts.multiline);
      expect(font.hookIds, [ForgeFontFamilySetting.systemFonts]);
      const required = ForgeFontFamilySetting(
        id: 'font',
        storage: ForgeSettingStorage('f'),
        label: _label,
        defaultValue: 'Menlo',
        allowEmpty: false,
        fontsProvider: null,
      );
      expect(required.validate(' '), ForgeConfigurationTexts.required);
      expect(required.hookIds, isEmpty);
    });
  });

  group('actions and status lines', () {
    const reload = ForgeActionSetting(
      id: 'reload',
      label: _label,
      action: 'forge.reloadConfiguration',
    );
    const issues = ForgeStatusSetting(
      id: 'issues',
      label: _label,
      status: 'forge.configurationIssues',
    );

    test('keep no value and need no storage', () {
      for (final setting in <ForgeSetting<Object>>[reload, issues]) {
        expect(setting.storesValue, isFalse);
        expect(setting.hasValue, isFalse);
        expect(setting.encode(ForgeNoValue.instance), isNull);
        expect(setting.read('anything').value, ForgeNoValue.instance);
      }
      expect(reload.hookIds, ['forge.reloadConfiguration']);
      expect(issues.hookIds, ['forge.configurationIssues']);
      const description = ForgeConfigurationDescription(
        id: 'd',
        title: _label,
        sections: [
          ForgeSettingsSection(
            id: 's',
            title: _label,
            settings: [reload, issues],
          ),
        ],
      );
      expect(description.problems(), isEmpty);
      expect(description.contains(reload), isTrue);
    });

    test('a valued kind without storage is a problem', () {
      const description = ForgeConfigurationDescription(
        id: 'd',
        title: _label,
        sections: [
          ForgeSettingsSection(
            id: 's',
            title: _label,
            settings: [
              ForgeBoolSetting(
                id: 'b',
                storage: ForgeSettingStorage.none(),
                label: _label,
                defaultValue: true,
              ),
            ],
          ),
        ],
      );
      expect(description.problems(), ['b has no storage key']);
    });
  });

  group('key strokes and chords', () {
    test('a shortcut override (forge.shortcuts.overrides entry)', () {
      const setting = ForgeKeyBindingSetting(
        id: 'k',
        storage: ForgeSettingStorage('k'),
        label: _label,
        requireModifier: true,
      );
      final stored = _stroke(_keyB, primary: true, shift: true);
      final stroke = setting.decode(stored)!;
      expect(stroke.primaryModifier && stroke.shift, isTrue);
      expect(setting.encode(stroke), stored);
      expect(setting.decode(jsonEncode(stored)), stroke);
      expect(setting.decode({'keyId': 'b'}), isNull);
      expect(setting.encode(ForgeKeyStroke.none), {'keyId': 0});
      expect(setting.validate(ForgeKeyStroke.none), isNull);
      expect(
        setting.validate(const ForgeKeyStroke(_keyB)),
        ForgeConfigurationTexts.modifierRequired,
      );
    });

    test('a chord override (forge.shortcuts.chordOverrides entry)', () {
      const setting = ForgeKeyChordSetting(
        id: 'c',
        storage: ForgeSettingStorage('c'),
        label: _label,
        maxStrokes: 3,
      );
      final stored = {
        'firstKey': _stroke(_keyK, primary: true),
        'secondKey': _stroke(_keyC, primary: true),
      };
      final chord = setting.decode(stored)!;
      expect(chord.strokes, [
        _primaryK,
        const ForgeKeyStroke(_keyC, primaryModifier: true),
      ]);
      expect(setting.encode(chord), stored);

      final three = ForgeKeyChord([_primaryK, _primaryB, _controlB]);
      final encoded = setting.encode(three)! as Map;
      expect(encoded['moreKeys'], [_stroke(_keyB, control: true)]);
      expect(setting.decode(encoded), three);
      expect(setting.encode(ForgeKeyChord.none), <String, Object?>{});
      expect(setting.decode(<String, Object?>{}), ForgeKeyChord.none);
      expect(
        setting.validate(ForgeKeyChord([_primaryK])),
        ForgeConfigurationTexts.chordLength(2, 3),
      );
      expect(
        setting.validate(
          ForgeKeyChord([_primaryK, _primaryK, _primaryK, _primaryK]),
        ),
        ForgeConfigurationTexts.chordLength(2, 3),
      );
    });

    test('pressed alike: primary is Control off macOS', () {
      expect(_primaryB.pressesLike(_controlB, primaryIsMeta: false), isTrue);
      expect(_primaryB.pressesLike(_controlB, primaryIsMeta: true), isFalse);
    });
  });

  group('key binding tables', () {
    final overridesDoc = jsonEncode({
      'md.bold': _stroke(_keyB, primary: true),
      'editor.save': _stroke(_enter, alt: true),
      'bad.entry': {'keyId': 'x'},
      'unbound': {'keyId': 0},
    });
    final chordsDoc = jsonEncode({
      'workbench.openRecent': {
        'firstKey': _stroke(_keyK, primary: true),
        'secondKey': _stroke(_keyC),
      },
      'bad': {'firstKey': _stroke(_keyK)},
    });

    test('reads Forge\'s overrides JSON text, skips malformed entries', () {
      final table = _shortcuts.read(overridesDoc).value;
      expect(table.overrides.keys, {'md.bold', 'editor.save'});
      expect(table.overrides['md.bold'], ForgeKeyChord.single(_primaryB));
      // Written back as Forge writes it.
      expect(_shortcuts.encode(table), {
        'md.bold': _stroke(_keyB, primary: true),
        'editor.save': _stroke(_enter, alt: true),
      });
      expect(_shortcuts.decode(_shortcuts.encode(table)), table);
    });

    test('reads Forge\'s chord overrides; a single key is no chord', () {
      final table = _chordTable.read(chordsDoc);
      expect(table.problem, isNull);
      expect(table.value.overrides.keys, ['workbench.openRecent']);
      final chords = _chordTable.decode(jsonDecode(chordsDoc))!;
      expect(chords.overrides['workbench.openRecent']!.strokes, hasLength(2));
      final written = _chordTable.encode(chords)! as Map;
      expect(written['workbench.openRecent'], {
        'firstKey': _stroke(_keyK, primary: true),
        'secondKey': _stroke(_keyC),
      });
    });

    test(
      'deleted bindings: the companion list (JSON text as Forge keeps it)',
      () {
        expect(_shortcuts.companions, [_deleted]);
        expect(_deleted.read(jsonEncode(['md.italic'])).value, ['md.italic']);
        const description = ForgeConfigurationDescription(
          id: 'keys',
          title: _label,
          sections: [
            ForgeSettingsSection(
              id: 's',
              title: _label,
              settings: [_shortcuts],
            ),
          ],
        );
        expect(description.settingById('deletedBindings'), _deleted);
        expect(description.contains(_deleted), isTrue);
        expect(description.problems(), isEmpty);
      },
    );

    test('override, wildcard, reset all', () {
      var table = ForgeKeyBindingTable.empty.withOverride(
        'md.bold',
        ForgeKeyChord.single(_primaryB),
      );
      expect(_shortcuts.offersWildcard('md.bold'), isTrue);
      expect(_shortcuts.offersWildcard('editor.save'), isFalse);
      table = table.withWildcard('md.bold', ForgeKeyChord.single(_controlB));
      expect(table.overrides.keys, ['*.bold']);
      expect(forgeWildcardActionId('*.bold'), isNull);
      expect(forgeSameActionFamily('*.bold', 'dart.bold'), isTrue);
      expect(table.resetAll(), ForgeKeyBindingTable.empty);
    });

    const actions = [
      ForgeCatalogueAction(
        id: 'md.bold',
        label: 'Bold',
        scope: 'md',
        defaultBinding: ForgeKeyChord([_primaryB]),
        group: 'Markdown',
      ),
      ForgeCatalogueAction(
        id: 'dart.build',
        label: 'Build',
        scope: 'dart',
        defaultBinding: ForgeKeyChord([_primaryB]),
      ),
      ForgeCatalogueAction(
        id: 'app.bookmarks',
        label: 'Bookmarks',
        defaultBinding: ForgeKeyChord([_primaryK]),
      ),
      ForgeCatalogueAction(
        id: 'app.recent',
        label: 'Recent',
        defaultBinding: ForgeKeyChord([_primaryK, ForgeKeyStroke(_keyC)]),
      ),
    ];

    test('rows: defaults, overrides, deleted, wildcard rows', () {
      final table = ForgeKeyBindingTable({
        'app.bookmarks': ForgeKeyChord.single(_controlB),
        '*.bold': ForgeKeyChord.single(_primaryK),
      });
      final rows = forgeKeyBindingRows(actions, table, deleted: {'dart.build'});
      expect(rows.map((r) => r.action.id), [
        'md.bold',
        'dart.build',
        'app.bookmarks',
        '*.bold',
      ]);
      expect(rows[1].deleted, isTrue);
      expect(rows[1].binding.isNone, isTrue);
      expect(rows[2].overridden, isTrue);
      expect(rows[3].wildcard, isTrue);
      expect(rows[3].action.label, 'Bold');
      final chordRows = forgeKeyBindingRows(actions, table, chords: true);
      expect(chordRows.map((r) => r.action.id), ['app.recent']);
    });

    test('conflicts: same keys in overlapping scopes, chord prefixes', () {
      final rows = forgeKeyBindingRows(
        actions,
        ForgeKeyBindingTable({
          // Control+B: off macOS the same keys as primary+B.
          'app.bookmarks': ForgeKeyChord.single(_controlB),
        }),
      );
      final allRows = [
        ...rows,
        ...forgeKeyBindingRows(
          actions,
          ForgeKeyBindingTable.empty,
          chords: true,
        ),
      ];
      final offMac = forgeKeyBindingConflicts(allRows, primaryIsMeta: false);
      final same = offMac.where((c) => c.kind == ForgeKeyConflictKind.same);
      // md.bold and dart.build differ in scope: no conflict between them,
      // but each collides with the global app.bookmarks.
      expect(same.single.actionIds, ['md.bold', 'dart.build', 'app.bookmarks']);

      final onMac = forgeKeyBindingConflicts(allRows, primaryIsMeta: true);
      expect(onMac.where((c) => c.kind == ForgeKeyConflictKind.same), isEmpty);

      final prefix = forgeKeyBindingConflicts(
        forgeKeyBindingRows(actions, ForgeKeyBindingTable.empty) +
            forgeKeyBindingRows(
              actions,
              ForgeKeyBindingTable.empty,
              chords: true,
            ),
        primaryIsMeta: true,
      ).where((c) => c.kind == ForgeKeyConflictKind.prefix);
      expect(prefix.single.actionIds, ['app.bookmarks', 'app.recent']);
    });

    test('one family never conflicts with itself', () {
      final rows = forgeKeyBindingRows(
        actions,
        ForgeKeyBindingTable({'*.bold': ForgeKeyChord.single(_primaryB)}),
      ).where((r) => r.action.id.endsWith('bold')).toList();
      expect(forgeKeyBindingConflicts(rows, primaryIsMeta: true), isEmpty);
    });
  });

  group('dates and times', () {
    test('date: YYYY-MM-DD, none as "", bounds', () {
      const setting = ForgeDateSetting(
        id: 'd',
        storage: ForgeSettingStorage('d'),
        label: _label,
        first: ForgeDate(2026, 1, 1),
        last: ForgeDate(2026, 12, 31),
      );
      const date = ForgeDate(2026, 11, 25);
      expect(setting.encode(date), '2026-11-25');
      expect(setting.decode('2026-11-25'), date);
      expect(setting.decode(DateTime(2026, 11, 25, 13)), date);
      expect(setting.decode('2026-02-30'), isNull);
      expect(setting.encode(ForgeDate.none), '');
      expect(setting.read('').value, ForgeDate.none);
      expect(setting.validate(ForgeDate.none), isNull);
      expect(
        setting.validate(const ForgeDate(2025, 12, 31)),
        ForgeConfigurationTexts.notBefore('2026-01-01'),
      );
      expect(
        setting.validate(const ForgeDate(2027, 1, 1)),
        ForgeConfigurationTexts.notAfter('2026-12-31'),
      );
      expect(date.toDateTime(), DateTime(2026, 11, 25));
      const required = ForgeDateSetting(
        id: 'd',
        storage: ForgeSettingStorage('d'),
        label: _label,
        defaultValue: ForgeDate(2026, 1, 1),
        allowNone: false,
      );
      expect(
        required.validate(ForgeDate.none),
        ForgeConfigurationTexts.required,
      );
    });

    test('time: HH:MM, bounds', () {
      const setting = ForgeTimeSetting(
        id: 't',
        storage: ForgeSettingStorage('t'),
        label: _label,
        defaultValue: ForgeTimeOfDay(9, 0),
        earliest: ForgeTimeOfDay(8, 0),
        latest: ForgeTimeOfDay(18, 30),
      );
      expect(setting.encode(const ForgeTimeOfDay(9, 5)), '09:05');
      expect(setting.decode('7:45'), const ForgeTimeOfDay(7, 45));
      expect(setting.decode('24:00'), isNull);
      expect(
        setting.validate(const ForgeTimeOfDay(7, 45)),
        ForgeConfigurationTexts.notBefore('08:00'),
      );
      expect(
        setting.validate(const ForgeTimeOfDay(19, 0)),
        ForgeConfigurationTexts.notAfter('18:30'),
      );
      expect(setting.validate(const ForgeTimeOfDay(12, 0)), isNull);
    });

    test('date and time: ISO 8601, local or UTC, bounds', () {
      const local = ForgeDateTimeSetting(
        id: 'dt',
        storage: ForgeSettingStorage('dt'),
        label: _label,
        first: ForgeDateTime(ForgeDate(2026, 1, 1), ForgeTimeOfDay(0, 0)),
      );
      const value = ForgeDateTime(
        ForgeDate(2026, 11, 25),
        ForgeTimeOfDay(14, 30),
        second: 5,
      );
      expect(local.encode(value), '2026-11-25T14:30:05');
      expect(local.decode('2026-11-25T14:30:05'), value);
      expect(local.encode(ForgeDateTime.none), '');
      expect(local.read('').value, ForgeDateTime.none);
      expect(local.decode('not a date'), isNull);
      expect(
        local.validate(
          const ForgeDateTime(ForgeDate(2025, 6, 1), ForgeTimeOfDay(0, 0)),
        ),
        ForgeConfigurationTexts.notBefore('2026-01-01T00:00:00'),
      );

      const utc = ForgeDateTimeSetting(
        id: 'u',
        storage: ForgeSettingStorage('u'),
        label: _label,
        utc: true,
      );
      final read = utc.decode('2026-11-25T14:30:00Z')!;
      expect(read.utc, isTrue);
      expect(utc.encode(read), '2026-11-25T14:30:00Z');
      // A local value is converted to UTC.
      final converted = utc.decode(DateTime(2026, 11, 25, 14, 30))!;
      expect(converted.utc, isTrue);
      expect(converted.toDateTime(), DateTime(2026, 11, 25, 14, 30).toUtc());
    });
  });

  test('every new kind is listed', () {
    expect(
      ForgeSettingKinds.all,
      containsAll([
        ForgeSettingKinds.fontFamily,
        ForgeSettingKinds.keyBinding,
        ForgeSettingKinds.keyChord,
        ForgeSettingKinds.keyBindingTable,
        ForgeSettingKinds.toolPath,
        ForgeSettingKinds.action,
        ForgeSettingKinds.status,
        ForgeSettingKinds.date,
        ForgeSettingKinds.time,
        ForgeSettingKinds.dateTime,
      ]),
    );
    expect(
      ForgeSettingKinds.all.toSet(),
      hasLength(ForgeSettingKinds.all.length),
    );
  });
}

/// A one-time-code flow: asks for a code, refuses a wrong one, waits once,
/// then answers a token.
class _FakeFlow extends ForgeSettingFlow {
  @override
  String get id => 'otp';

  @override
  ForgeText get label => const ForgeText('otp', 'Enter code');

  @override
  ForgeFlowSession start(ForgeSettingContext context) => _FakeSession();
}

class _FakeSession implements ForgeFlowSession {
  String? _code;

  static const _ask = [
    ForgeFlowField(
      id: 'code',
      label: ForgeText('code', 'Code'),
      kind: ForgeFlowFieldKind.oneTimeCode,
      length: 6,
    ),
  ];

  @override
  Future<ForgeFlowStep> start() async =>
      const ForgeFlowStep.input(fields: _ask);

  @override
  Future<ForgeFlowStep> respond(ForgeFlowResponse response) async {
    final code = response.values['code'];
    if (code != '123456') {
      return const ForgeFlowStep.input(
        fields: _ask,
        error: ForgeText('wrong', 'Wrong code'),
      );
    }
    _code = code;
    return const ForgeFlowStep.waiting(pollAfter: Duration.zero);
  }

  @override
  Future<ForgeFlowStep> poll() async =>
      ForgeFlowStep.done(ForgeActionResult.success(value: 'token-$_code'));

  @override
  void cancel() {}
}

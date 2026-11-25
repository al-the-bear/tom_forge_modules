import 'package:test/test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

const _theme = ForgeChoiceSetting(
  id: 'theme',
  storage: ForgeSettingStorage('forge.appearance.themeMode'),
  label: ForgeText('forge.shell.theme', 'Theme'),
  defaultValue: 'system',
  choices: [
    ForgeSettingChoice('dark', ForgeText('forge.shell.theme.dark', 'Dark')),
    ForgeSettingChoice('light', ForgeText('forge.shell.theme.light', 'Light')),
    ForgeSettingChoice(
      'system',
      ForgeText('forge.shell.theme.system', 'System'),
    ),
  ],
);

const _maxRecent = ForgeIntSetting(
  id: 'maxRecent',
  storage: ForgeSettingStorage('forge.startup.maxRecentWorkspaces'),
  label: ForgeText('forge.shell.maxRecent', 'Max recent'),
  defaultValue: 10,
  min: 1,
  max: 50,
);

const _fontSize = ForgeDoubleSetting(
  id: 'fontSize',
  storage: ForgeSettingStorage(
    'forge.editor.textSettings',
    path: ['dart', 'fontSize'],
  ),
  label: ForgeText('forge.editor.fontSize', 'Size'),
  defaultValue: 14,
  min: 6,
  max: 72,
  enabledWhen: ForgeSettingCondition.isTrue('custom'),
);

const _custom = ForgeBoolSetting(
  id: 'custom',
  storage: ForgeSettingStorage('forge.editor.custom'),
  label: ForgeText('forge.editor.custom', 'Custom'),
);

void main() {
  group('ForgeText', () {
    test('falls back to the English text with its parameters filled', () {
      const text = ForgeText('k', 'At least {min}.', params: {'min': 3});
      expect(text.resolve(), 'At least 3.');
      expect(text.toString(), 'At least 3.');
    });

    test('takes the lookup\'s text when it has one', () {
      const text = ForgeText('k', 'At least {min}.', params: {'min': 3});
      expect(
        text.resolve((key) => key == 'k' ? 'Mindestens {min}.' : null),
        'Mindestens 3.',
      );
      expect(text.resolve((_) => null), 'At least 3.');
    });

    test('resolves a ForgeText parameter with the same lookup', () {
      final text = ForgeConfigurationTexts.item(
        'x',
        ForgeConfigurationTexts.required,
      );
      expect(text.resolve(), '"x": A value is required.');
      expect(
        text.resolve(
          (key) => key == ForgeConfigurationTexts.required.key
              ? 'Pflichtfeld.'
              : null,
        ),
        '"x": Pflichtfeld.',
      );
    });

    test('equality by key, fallback and parameters', () {
      expect(const ForgeText('a', 'A'), const ForgeText('a', 'A'));
      expect(
        ForgeConfigurationTexts.min(1),
        isNot(ForgeConfigurationTexts.min(2)),
      );
    });
  });

  group('setting kinds', () {
    test('bool decodes bools only', () {
      expect(_custom.decode(true), isTrue);
      expect(_custom.decode('true'), isNull);
      expect(_custom.kind, ForgeSettingKinds.boolean);
    });

    test('int checks its bounds and takes integral doubles', () {
      expect(_maxRecent.decode(5), 5);
      expect(_maxRecent.decode(5.0), 5);
      expect(_maxRecent.decode(5.5), isNull);
      expect(_maxRecent.validate(0), ForgeConfigurationTexts.min(1));
      expect(_maxRecent.validate(51), ForgeConfigurationTexts.max(50));
      expect(_maxRecent.validate(50), isNull);
      expect(_maxRecent.check('7'), ForgeConfigurationTexts.wrongType);
    });

    test('double takes any finite number', () {
      expect(_fontSize.decode(12), 12.0);
      expect(_fontSize.decode(double.nan), isNull);
      expect(_fontSize.validate(80).toString(), 'At most 72.0.');
    });

    test('string: required, single line, length and pattern', () {
      const name = ForgeStringSetting(
        id: 'name',
        storage: ForgeSettingStorage('n'),
        label: ForgeText('n', 'Name'),
        defaultValue: 'a',
        allowEmpty: false,
        maxLength: 5,
        pattern: '[a-z]+',
      );
      expect(name.validate(''), ForgeConfigurationTexts.required);
      expect(name.validate('a\nb'), ForgeConfigurationTexts.multiline);
      expect(name.validate('abcdef'), ForgeConfigurationTexts.maxLength(5));
      expect(name.validate('ab1'), ForgeConfigurationTexts.pattern('[a-z]+'));
      expect(name.validate('abc'), isNull);
    });

    test('choice accepts its values only', () {
      expect(_theme.validate('dark'), isNull);
      expect(_theme.validate('blue'), ForgeConfigurationTexts.choice);
      expect(_theme.choiceOf('light')!.label.fallback, 'Light');
    });

    test('string list: items, duplicates, choices, pattern, JSON text', () {
      const extensions = ForgeStringListSetting(
        id: 'ext',
        storage: ForgeSettingStorage('e'),
        label: ForgeText('e', 'Extensions'),
        itemPattern: r'[a-z0-9.]+',
      );
      expect(extensions.decode(['a', 'b']), ['a', 'b']);
      expect(extensions.decode('["a"]'), ['a']);
      expect(extensions.decode([1]), isNull);
      expect(
        extensions.validate(['a', 'a']),
        ForgeConfigurationTexts.duplicate('a'),
      );
      expect(extensions.validate(['A']), isNotNull);
      expect(extensions.validate(['png', 'g.dart']), isNull);
      expect(extensions.sameValue(['a'], ['a']), isTrue);

      const picked = ForgeStringListSetting(
        id: 'picked',
        storage: ForgeSettingStorage('p'),
        label: ForgeText('p', 'Picked'),
        choices: [ForgeSettingChoice('x', ForgeText('x', 'X'))],
      );
      expect(picked.validate(['x']), isNull);
      expect(picked.validate(['y']), isNotNull);
    });

    test('path: required when not allowEmpty', () {
      const shell = ForgePathSetting(
        id: 'shell',
        storage: ForgeSettingStorage('s'),
        label: ForgeText('s', 'Shell'),
        allowEmpty: false,
        defaultValue: '/bin/sh',
      );
      expect(shell.validate(''), ForgeConfigurationTexts.required);
      expect(shell.validate('/bin/zsh'), isNull);
    });

    test('color: hex text and opacity', () {
      const accent = ForgeColorSetting(
        id: 'accent',
        storage: ForgeSettingStorage('c'),
        label: ForgeText('c', 'Accent'),
        defaultValue: 0xFF007ACC,
      );
      expect(accent.decode('#007acc'), 0xFF007ACC);
      expect(accent.decode('#80007ACC'), 0x80007ACC);
      expect(accent.decode('blue'), isNull);
      expect(accent.validate(0x80007ACC), ForgeConfigurationTexts.wrongType);
      expect(ForgeColorSetting.toHex(0xFF007ACC), '#007ACC');
      expect(ForgeColorSetting.toHex(0x80007ACC), '#80007ACC');
    });

    test('string map: keys, values, choices, JSON text', () {
      const types = ForgeStringMapSetting(
        id: 'types',
        storage: ForgeSettingStorage('t'),
        label: ForgeText('t', 'File types'),
        keyPattern: r'\.[a-z0-9]+',
        valueChoices: [
          ForgeSettingChoice('md', ForgeText('md', 'Markdown')),
          ForgeSettingChoice('yaml', ForgeText('yaml', 'YAML')),
        ],
      );
      expect(types.decode('{".md":"md"}'), {'.md': 'md'});
      expect(types.decode({'.md': 1}), isNull);
      expect(types.validate({'.md': 'md'}), isNull);
      expect(types.validate({'md': 'md'}), isNotNull);
      expect(types.validate({'.md': 'dart'}), isNotNull);
      expect(types.sameValue({'a': 'b'}, {'a': 'b'}), isTrue);
    });

    test('read: default when absent, default and a problem when invalid', () {
      final absent = _maxRecent.read(null);
      expect(absent.value, 10);
      expect(absent.stored, isFalse);
      expect(absent.problem, isNull);

      final stored = _maxRecent.read(20);
      expect(stored.value, 20);
      expect(stored.stored, isTrue);

      final outOfRange = _maxRecent.read(99);
      expect(outOfRange.value, 10);
      expect(outOfRange.problem, ForgeConfigurationTexts.max(50));

      final wrong = _maxRecent.read('x');
      expect(wrong.value, 10);
      expect(wrong.problem, ForgeConfigurationTexts.wrongType);
    });
  });

  group('ForgeSettingCondition', () {
    test('isTrue, equals and oneOf', () {
      expect(const ForgeSettingCondition.isTrue('a').holds(true), isTrue);
      expect(const ForgeSettingCondition.isTrue('a').holds(false), isFalse);
      expect(const ForgeSettingCondition.equals('a', 'x').holds('x'), isTrue);
      expect(
        const ForgeSettingCondition.oneOf('a', ['x', 'y']).holds('y'),
        isTrue,
      );
      expect(
        const ForgeSettingCondition.oneOf('a', ['x', 'y']).holds('z'),
        isFalse,
      );
    });
  });

  group('ForgeConfigurationDescription', () {
    const description = ForgeConfigurationDescription(
      id: 'forge.shell',
      title: ForgeText('forge.shell', 'Shell'),
      sections: [
        ForgeSettingsSection(
          id: 'appearance',
          title: ForgeText('forge.shell.appearance', 'Appearance'),
          icon: ForgeIconRef(0xe1b1),
          settings: [_theme, _maxRecent],
        ),
        ForgeSettingsSection(
          id: 'editor',
          title: ForgeText('forge.shell.editor', 'Editor'),
          settings: [_custom, _fontSize],
        ),
      ],
    );

    test('finds settings and sections', () {
      expect(description.settings.map((s) => s.id), [
        'theme',
        'maxRecent',
        'custom',
        'fontSize',
      ]);
      expect(description.settingById('fontSize'), same(_fontSize));
      expect(description.sectionById('editor')!.settings, hasLength(2));
      expect(description.settingById('nope'), isNull);
    });

    test('a sound description has no problems', () {
      expect(description.problems(), isEmpty);
    });

    test('problems: duplicates, shared storage, bad default, conditions', () {
      const broken = ForgeConfigurationDescription(
        id: 'broken',
        title: ForgeText('b', 'Broken'),
        sections: [
          ForgeSettingsSection(
            id: 's',
            title: ForgeText('s', 'S'),
            settings: [
              _maxRecent,
              ForgeIntSetting(
                id: 'maxRecent',
                storage: ForgeSettingStorage(
                  'forge.startup.maxRecentWorkspaces',
                ),
                label: ForgeText('x', 'X'),
                defaultValue: 0,
                min: 1,
              ),
              _fontSize,
            ],
          ),
          ForgeSettingsSection(
            id: 's',
            title: ForgeText('s', 'S'),
            settings: [],
          ),
        ],
      );
      final problems = broken.problems();
      expect(problems, contains(contains('section id "s" twice')));
      expect(problems, contains(contains('setting id "maxRecent" twice')));
      expect(
        problems,
        contains(contains('stored at forge.startup.maxRecentWorkspaces')),
      );
      expect(problems, contains(contains('the default of maxRecent')));
      expect(problems, contains(contains('condition on "custom"')));
    });

    test('storage locations', () {
      expect(
        _fontSize.storage.location,
        'forge.editor.textSettings/dart/fontSize',
      );
      expect(
        const ForgeSettingStorage('a', path: ['b']),
        const ForgeSettingStorage('a', path: ['b']),
      );
    });
  });

  test('forgeOrderedSections orders by section order, stable', () {
    const a = ForgeConfigurationDescription(
      id: 'a',
      title: ForgeText('a', 'A'),
      sections: [
        ForgeSettingsSection(
          id: 'late',
          title: ForgeText('l', 'L'),
          order: 200,
          settings: [],
        ),
        ForgeSettingsSection(
          id: 'first',
          title: ForgeText('f', 'F'),
          settings: [],
        ),
      ],
    );
    const b = ForgeConfigurationDescription(
      id: 'b',
      title: ForgeText('b', 'B'),
      sections: [
        ForgeSettingsSection(
          id: 'early',
          title: ForgeText('e', 'E'),
          order: 10,
          settings: [],
        ),
        ForgeSettingsSection(
          id: 'second',
          title: ForgeText('s', 'S'),
          settings: [],
        ),
      ],
    );
    expect(forgeOrderedSections([a, b]).map((r) => r.id), [
      'b/early',
      'a/first',
      'b/second',
      'a/late',
    ]);
  });
}

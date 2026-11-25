import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/text_types.dart' show ForgeTextSettings;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// A description like an editor type's: the shared text groups of `demo`
/// and one switch of its editor-specific configuration.
final _toggle = ForgeEditorSettings.toggle('demo', 'showToolbar', 'Toolbar');

final _description = ForgeConfigurationDescription(
  id: 'forge.editor.demo',
  title: const ForgeText('demo.title', 'Demo'),
  sections: [
    ForgeSettingsSection(
      id: 'editor',
      title: const ForgeText('demo.section', 'Demo Editor'),
      settings: [
        ...ForgeEditorSettings.textGroups('demo'),
        ForgeSettingsGroup(
          id: 'own',
          title: const ForgeText('demo.own', 'Own'),
          settings: [_toggle],
        ),
      ],
    ),
  ],
);

ForgeSetting<T> _setting<T extends Object>(String id) =>
    _description.sections.single.settings.firstWhere((s) => s.id == id)
        as ForgeSetting<T>;

void main() {
  group('ForgeEditorSettingBinding', () {
    late ForgeMemoryStateStore store;
    late ForgeKitPreferences prefs;
    late ForgeConfigurationValues values;

    Future<void> open({Map<String, Object?> initial = const {}}) async {
      store = ForgeMemoryStateStore(initial: initial);
      prefs = ForgeKitPreferences(stateStore: store);
      await prefs.load();
      values = ForgeConfigurationValues(
        store,
        descriptions: [_description],
        bindings: [ForgeEditorSettingBinding(prefs)],
      );
      addTearDown(values.dispose);
      await values.load();
    }

    test('the defaults are ForgeTextSettings\' own', () async {
      await open();
      const defaults = ForgeTextSettings();
      expect(values.valueOf(_setting<double>('fontSize')), defaults.fontSize);
      expect(values.valueOf(_setting<int>('tabSize')), defaults.tabSize);
      expect(values.valueOf(_setting<bool>('wordWrap')), defaults.wordWrap);
      expect(values.valueOf(_toggle), isTrue);
    });

    test('an existing user\'s stored settings are read unchanged', () async {
      await open(
        initial: {
          'forge.editor.textSettings':
              '{"demo":{"fontSize":18,"tabSize":4,"wordWrap":false}}',
          'forge.editor.specificConfig': '{"demo":{"showToolbar":false}}',
        },
      );
      expect(values.valueOf(_setting<double>('fontSize')), 18.0);
      expect(values.valueOf(_setting<int>('tabSize')), 4);
      expect(values.valueOf(_setting<bool>('wordWrap')), isFalse);
      expect(values.valueOf(_toggle), isFalse);
    });

    test(
      'a change goes through the preferences and is stored as before',
      () async {
        await open();
        var notified = 0;
        prefs.addListener(() => notified++);
        expect(await values.set(_setting<double>('fontSize'), 20.0), isNull);
        expect(await values.set(_toggle, false), isNull);
        await values.flushed();
        expect(prefs.getEditorTextSettings('demo').fontSize, 20.0);
        expect(prefs.getEditorSpecificConfig('demo')['showToolbar'], isFalse);
        expect(notified, greaterThan(0));
        final reread = ForgeKitPreferences(stateStore: store);
        await reread.load();
        expect(reread.getEditorTextSettings('demo').fontSize, 20.0);
        expect(reread.getEditorSpecificConfig('demo'), {'showToolbar': false});
      },
    );

    test('reset puts the default back', () async {
      await open();
      await values.set(_setting<int>('tabSize'), 8);
      await values.flushed();
      await values.reset(_setting<int>('tabSize'));
      await values.flushed();
      expect(prefs.getEditorTextSettings('demo').tabSize, 2);
      expect(values.valueOf(_setting<int>('tabSize')), 2);
    });

    test('a change made through the preferences reaches the values', () async {
      await open();
      final seen = Completer<void>();
      final listenable = values.listenable(_setting<double>('fontSize'));
      listenable.addListener(() {
        if (!seen.isCompleted) seen.complete();
      });
      prefs.setEditorTextSettings(
        'demo',
        const ForgeTextSettings(fontSize: 22),
      );
      await seen.future.timeout(const Duration(seconds: 2));
      expect(listenable.value, 22.0);
    });
  });
}

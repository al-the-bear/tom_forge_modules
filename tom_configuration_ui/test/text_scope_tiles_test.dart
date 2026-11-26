// A tile reads its description's texts under the scope of the module that
// contributed it (ForgeConfigurationValues.textScopeOf): one description
// shown for two modules mounted under two scopes has two wordings, and a
// description not migrated yet (keys with English fallbacks) shows its
// fallbacks as before.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

const _wrap = ForgeBoolSetting(
  id: 'wrap',
  storage: ForgeSettingStorage('scoped.wrap'),
  label: ForgeText.id('editing.wrapSwitch.label'),
  help: ForgeText.id('editing.wrapSwitch.subtitle'),
);

const _scoped = ForgeConfigurationDescription(
  id: 'scoped',
  title: ForgeText.id('editing.editingSection.title'),
  sections: [
    ForgeSettingsSection(
      id: 'editing',
      title: ForgeText.id('editing.editingSection.title'),
      settings: [_wrap],
    ),
  ],
);

const _old = ForgeConfigurationDescription(
  id: 'old',
  title: ForgeText('old.title', 'Old module'),
  sections: [
    ForgeSettingsSection(
      id: 'old',
      title: ForgeText('old.section', 'Old settings'),
      settings: [
        ForgeBoolSetting(
          id: 'flag',
          storage: ForgeSettingStorage('old.flag'),
          label: ForgeText('old.flag', 'An old flag'),
        ),
      ],
    ),
  ],
);

Map<String, dynamic> _texts(String section, String label) => {
  'editing': {
    'editingSection': {'title': section},
    'wrapSwitch': {'label': label, 'subtitle': '$label, explained'},
  },
};

void main() {
  setUp(() {
    installTexts({
      'left': _texts('Left editing', 'Wrap on the left'),
      'right': _texts('Right editing', 'Wrap on the right'),
    });
  });
  tearDown(clearTexts);

  testWidgets('one description, two module scopes, two wordings; an '
      'unmigrated one shows its fallbacks', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final values = ForgeConfigurationValues(
      ForgeMemoryStateStore(),
      descriptions: const [_scoped, _old],
      textScopes: {'scoped': runInScopePath('left', () => ForgeTextScope())},
    );
    addTearDown(values.dispose);
    await tester.runAsync(values.load);
    final right = runInScopePath('right', () => ForgeTextScope());
    final ref = forgeOrderedSections(const [_scoped]).single;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeConfigurationScope(
            values: values,
            child: ListView(
              children: [
                ...forgeConfigurationTiles(values),
                ForgeConfigurationTile.of(
                  ref,
                  key: const ValueKey('right'),
                  values: values,
                  textScope: right,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Left editing'), findsOneWidget);
    expect(find.text('Wrap on the left'), findsOneWidget);
    expect(find.text('Right editing'), findsOneWidget);
    expect(find.text('Wrap on the right'), findsOneWidget);
    expect(find.text('Old settings'), findsOneWidget);
    expect(find.text('An old flag'), findsOneWidget);
    expect(find.textContaining('editing.wrapSwitch'), findsNothing);
  });
}

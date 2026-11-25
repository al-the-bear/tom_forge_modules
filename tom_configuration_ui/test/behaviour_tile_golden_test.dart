// A tile of the setting kinds with behaviour as a golden, light and dark:
// a font, a group with a key binding and a chord, a tool path with its
// state, an action, a status line, a scaled number, a date and a colour.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomTextResourceProvider;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_ui_testing/tom_ui_testing.dart';

import 'support/behaviour_configuration.dart';
import 'support/demo_configuration.dart' show demoPage;

const _goldenSection = ForgeSettingsSection(
  id: 'golden',
  title: ForgeText('demo.golden', 'Tools and keys'),
  icon: ForgeIconRef(0xe369), // Icons.keyboard
  settings: [
    fontSetting,
    ForgeSettingsGroup(
      id: 'goldenKeys',
      title: ForgeText('demo.keys', 'Keyboard'),
      settings: [quickOpenSetting, chordSetting],
    ),
    toolSetting,
    reloadSetting,
    healthSetting,
    limitSetting,
    sinceSetting,
    highlightSetting,
  ],
);

const _goldenDescription = ForgeConfigurationDescription(
  id: 'golden',
  title: ForgeText('golden', 'Golden'),
  sections: [_goldenSection],
);

void main() {
  setUpAll(() async {
    await loadTomGoldenFonts();
    useTomTestlogComparator('test/behaviour_tile_golden_test.dart');
  });

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  tearDown(TomTextResourceProvider.clearAppResourceProvider);

  for (final (name, mode) in [
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    tomGoldenTestWidgets(
      'a tile of the kinds with behaviour in the $name theme',
      'configuration_behaviour_tile_$name',
      (tester) async {
        tester.view.physicalSize = const Size(560, 1240);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final hooks = BehaviourHooks();
        final store = ForgeMemoryStateStore(
          initial: {
            'demo.codeFont': 'JetBrains Mono',
            'demo.quickOpen': ForgeKeyStroke(
              LogicalKeyboardKey.keyP.keyId,
              primaryModifier: true,
            ).toJson(),
            'demo.chord': ForgeKeyChord([
              ForgeKeyStroke(
                LogicalKeyboardKey.keyK.keyId,
                primaryModifier: true,
              ),
              ForgeKeyStroke(LogicalKeyboardKey.keyS.keyId),
            ]).toChordJson(),
            'demo.limit': 8 * 1048576,
          },
        );
        final values = ForgeConfigurationValues(
          store,
          descriptions: [_goldenDescription],
          hooks: hooks.hooks,
        );
        await tester.runAsync(values.load);
        await tester.pumpWidget(
          demoPage(
            [ForgeConfigurationTile(section: _goldenSection, values: values)],
            themeMode: mode,
            tileWidth: 520,
          ),
        );
        await tester.pumpAndSettle();

        await expectTomShot(
          tester,
          shot: find.byType(ForgeConfigurationTile),
          content: find.byType(ForgeConfigurationTile),
          marker: 'Version 3.1',
          reason: 'the tile shows the tool path\'s state',
          path: 'goldens/configuration_behaviour_tile_$name.png',
        );

        await tester.pumpWidget(const SizedBox());
        values.dispose();
        await hooks.dispose();
      },
    );
  }
}

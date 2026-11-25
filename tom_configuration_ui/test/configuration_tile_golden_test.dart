// A configuration tile as a golden, light and dark, with the workspace's
// golden harness (tom_ui_testing: real fonts, failures in testlog/goldens/,
// readable and free of machine paths before the pixels are compared).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomTextResourceProvider;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_ui_testing/tom_ui_testing.dart';

import 'support/demo_configuration.dart';

void main() {
  setUpAll(() async {
    await loadTomGoldenFonts();
    useTomTestlogComparator('test/configuration_tile_golden_test.dart');
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
      'the Editing tile in the $name theme',
      'configuration_tile_$name',
      (tester) async {
        tester.view.physicalSize = const Size(440, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final store = ForgeMemoryStateStore(initial: {'demo.size': 8});
        final values = ForgeConfigurationValues(
          store,
          descriptions: [demoDescription],
        );
        await tester.runAsync(values.load);
        await tester.pumpWidget(
          demoPage([
            ForgeConfigurationTile(section: editingSection, values: values),
          ], themeMode: mode),
        );
        await tester.pumpAndSettle();

        await expectTomShot(
          tester,
          shot: find.byType(ForgeConfigurationTile),
          content: find.byType(ForgeConfigurationTile),
          marker: 'Tab size',
          reason: 'the tile shows its settings',
          path: 'goldens/configuration_tile_$name.png',
        );

        await tester.pumpWidget(const SizedBox());
        values.dispose();
      },
    );
  }
}

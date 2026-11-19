/// The shared look: the shell theme per mode, the Material theme it is
/// installed in, and the readable token pairs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';
import 'package:tom_ui_support/tom_ui_support.dart';

void main() {
  group('ForgeShellTheme.forMode', () {
    test('SUI-1: light and dark ignore the platform', () {
      for (final platform in Brightness.values) {
        expect(
          ForgeShellTheme.forMode(
            ThemeMode.light,
            platformBrightness: platform,
          ).panelSurface,
          ForgeShellTheme.light().panelSurface,
        );
        expect(
          ForgeShellTheme.forMode(
            ThemeMode.dark,
            platformBrightness: platform,
          ).panelSurface,
          ForgeShellTheme.dark().panelSurface,
        );
      }
    });

    test("SUI-2: system follows the platform's brightness", () {
      expect(
        ForgeShellTheme.forMode(
          ThemeMode.system,
          platformBrightness: Brightness.dark,
        ).panelSurface,
        ForgeShellTheme.dark().panelSurface,
      );
      expect(
        ForgeShellTheme.forMode(
          ThemeMode.system,
          platformBrightness: Brightness.light,
        ).panelSurface,
        ForgeShellTheme.light().panelSurface,
      );
    });

    test('SUI-3: high contrast wins in every mode', () {
      for (final mode in ThemeMode.values) {
        for (final platform in Brightness.values) {
          expect(
            ForgeShellTheme.forMode(
              mode,
              platformBrightness: platform,
              highContrast: true,
            ).panelSurface,
            ForgeShellTheme.highContrast().panelSurface,
          );
        }
      }
    });
  });

  test('SUI-4: forgeThemeData installs the matching shell theme', () {
    final light = forgeThemeData(Brightness.light);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(
      light.extension<ForgeShellTheme>()!.panelSurface,
      ForgeShellTheme.light().panelSurface,
    );
    final dark = forgeThemeData(Brightness.dark);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(
      dark.extension<ForgeShellTheme>()!.panelSurface,
      ForgeShellTheme.dark().panelSurface,
    );
    for (final b in Brightness.values) {
      final hc = forgeThemeData(b, highContrast: true);
      expect(hc.colorScheme.brightness, Brightness.dark);
      expect(
        hc.extension<ForgeShellTheme>()!.panelSurface,
        ForgeShellTheme.highContrast().panelSurface,
      );
    }
  });

  test('SUI-5: the chord popup text is readable (WCAG AA) in every set', () {
    for (final (name, theme) in [
      ('dark', ForgeShellTheme.dark()),
      ('light', ForgeShellTheme.light()),
      ('high contrast', ForgeShellTheme.highContrast()),
    ]) {
      expect(
        tomContrastRatio(
          theme.chordPopupForeground,
          theme.chordPopupBackground,
        ),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    }
  });

  test('SUI-6: reduced motion makes every animation instant and linear', () {
    addTearDown(() => ForgeAnimations.reduceMotion = false);
    expect(ForgeAnimations.panelTransition, isNot(Duration.zero));
    ForgeAnimations.reduceMotion = true;
    for (final d in [
      ForgeAnimations.panelTransition,
      ForgeAnimations.tabTransition,
      ForgeAnimations.dropZoneFade,
      ForgeAnimations.shortcutPopupIn,
      ForgeAnimations.shortcutPopupOut,
      ForgeAnimations.notificationIn,
      ForgeAnimations.notificationOut,
    ]) {
      expect(d, Duration.zero);
    }
    for (final c in [
      ForgeAnimations.panelCurve,
      ForgeAnimations.tabCurve,
      ForgeAnimations.popupCurve,
    ]) {
      expect(c, Curves.linear);
    }
  });

  test('SUI-7: the dimensions the shell lays out with', () {
    expect(ForgeDimensions.statusBarHeight, 24);
    expect(ForgeDimensions.titleBarHeight, 48);
    expect(ForgeDimensions.panelMinSize, 50);
  });
}

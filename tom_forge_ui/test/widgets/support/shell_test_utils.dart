import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgePanelLocation, ForgeSetting;
import 'package:tom_forge_ui/tom_forge_ui.dart' show ForgeShellScaffold;

Future<void> prepareLargeSurface(
  WidgetTester tester, {
  Size size = const Size(2200, 2400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> sendPrimaryShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  final usesMeta = defaultTargetPlatform == TargetPlatform.macOS;
  final primary = usesMeta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;

  await tester.sendKeyDownEvent(primary);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(primary);
}

void suppressOverflowErrorsForTest() {
  final oldOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = oldOnError);
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
}

// ── The configuration side panel's described settings ──
// The Shell and Terminal sections are configuration descriptions
// (ForgeShellConfiguration) drawn as tiles: every setting is an entry keyed
// by its storage location.

/// The entry of [setting] in a configuration tile.
Finder configSettingEntry(ForgeSetting<Object> setting) => find.byKey(
  ValueKey('forge.configuration.setting.${setting.storage.location}'),
);

/// The text field of [setting]'s entry.
Finder configSettingField(ForgeSetting<Object> setting) => find.descendant(
  of: configSettingEntry(setting),
  matching: find.byType(TextField),
);

/// The switch of a bool [setting]'s entry.
Finder configSettingSwitch(ForgeSetting<Object> setting) => find.descendant(
  of: configSettingEntry(setting),
  matching: find.byType(Switch),
);

/// Whether the switch of a bool [setting]'s entry is on.
bool configSettingSwitchValue(
  WidgetTester tester,
  ForgeSetting<Object> setting,
) => tester.widget<Switch>(configSettingSwitch(setting)).value;

/// Scrolls [finder] (inside a configuration tile) into view in the
/// tile's own scroll view only: `ensureVisible` would scroll the panels
/// around it too and leave it under the panel's header.
///
/// The tile is laid out at least as wide as the panel content's minimum
/// (400 px); the left panel is widened to it first, so the controls at the
/// end of a row (a switch, an *Add* button) are not under the editor area.
Future<void> _showInTile(WidgetTester tester, Finder finder) async {
  final scaffolds = find.byType(ForgeShellScaffold);
  if (scaffolds.evaluate().isNotEmpty) {
    final layout = tester
        .widget<ForgeShellScaffold>(scaffolds.first)
        .layoutController;
    if (layout.leftPanel.value.size < 520) {
      layout.setPanelSize(ForgePanelLocation.left, 520);
      await tester.pumpAndSettle();
    }
  }
  final scrollable = find
      .ancestor(of: finder, matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(finder, 80, scrollable: scrollable);
  await tester.pumpAndSettle();
}

/// Types [text] into [setting]'s text field, scrolled into view first.
Future<void> enterConfigSetting(
  WidgetTester tester,
  ForgeSetting<Object> setting,
  String text,
) async {
  final field = configSettingField(setting);
  expect(field, findsOneWidget, reason: setting.id);
  await _showInTile(tester, field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Taps the switch of a bool [setting]'s entry, scrolled into view first.
Future<void> tapConfigSwitch(
  WidgetTester tester,
  ForgeSetting<Object> setting,
) async {
  final toggle = configSettingSwitch(setting);
  expect(toggle, findsOneWidget, reason: setting.id);
  await _showInTile(tester, toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Sets a bool [setting]'s switch to [expected] (taps it when it is not).
Future<void> setConfigSwitch(
  WidgetTester tester,
  ForgeSetting<Object> setting,
  bool expected,
) async {
  final toggle = configSettingSwitch(setting);
  expect(toggle, findsOneWidget, reason: setting.id);
  await _showInTile(tester, toggle);
  if (configSettingSwitchValue(tester, setting) != expected) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
}

/// Adds [item] to a string-list [setting] through its entry's field and
/// *Add* button.
Future<void> addConfigListItem(
  WidgetTester tester,
  ForgeSetting<Object> setting,
  String item,
) async {
  await enterConfigSetting(tester, setting, item);
  final add = find.descendant(
    of: configSettingEntry(setting),
    matching: find.widgetWithIcon(IconButton, Icons.add),
  );
  expect(add, findsOneWidget, reason: setting.id);
  await tester.tap(add);
  await tester.pumpAndSettle();
}

/// The error text shown in [setting]'s entry.
Finder configSettingError(ForgeSetting<Object> setting, String text) =>
    find.descendant(of: configSettingEntry(setting), matching: find.text(text));

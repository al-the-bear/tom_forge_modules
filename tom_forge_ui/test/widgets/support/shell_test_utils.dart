import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeSetting;
import 'package:tom_configuration_ui/tom_configuration_ui.dart'
    show ForgeConfigurationScope;
import 'package:tom_forge_ui/tom_forge_ui.dart'
    show
        ForgeDartEditorConfiguration,
        ForgeFileTypesConfiguration,
        ForgeMarkdownEditorConfiguration,
        ForgeYamlEditorConfiguration;

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

/// The Dart editor's setting [id] (its configuration description).
ForgeSetting<Object> dartEditorSetting(String id) =>
    ForgeDartEditorConfiguration.description.settingById(id)!;

/// The YAML editor's setting [id] (its configuration description).
ForgeSetting<Object> yamlEditorSetting(String id) =>
    ForgeYamlEditorConfiguration.description.settingById(id)!;

/// The Markdown editor's setting [id] (its configuration description).
ForgeSetting<Object> markdownEditorSetting(String id) =>
    ForgeMarkdownEditorConfiguration.description.settingById(id)!;

/// The search box of the shell's key binding table: *Shortcuts*, or with
/// [chords] *Chord Shortcuts* (ForgeShortcutConfiguration).
Finder shortcutTableSearch({bool chords = false}) => find.byKey(
  ValueKey(
    'forge.configuration.keyTable.search.${chords ? 'chords' : 'shortcuts'}',
  ),
);

/// The *Reset all* button of the shell's *Shortcuts* table.
Finder shortcutTableResetAll() => find.byKey(
  const ValueKey('forge.configuration.keyTable.resetAll.shortcuts'),
);

// ── File Types (ForgeFileTypesConfiguration: one association table) ──

const _fileTypesId = 'associations';

/// The editor id a File Types choice names by its title.
String fileTypeEditorIdOf(String title) => switch (title) {
  'Markdown' => 'md',
  'Dart' => 'dart',
  'YAML' => 'yaml',
  'Plain Text' => 'plaintext',
  _ => title,
};

/// The row of [extension] (`*` for the default editor).
Finder fileTypeRow(String extension) =>
    find.byKey(ValueKey('forge.configuration.map.$_fileTypesId.$extension'));

/// The new extension's field.
Finder fileTypeNewExtensionField() =>
    find.byKey(const ValueKey('forge.configuration.map.$_fileTypesId.newKey'));

/// The remove button of [extension]'s row.
Finder fileTypeRemoveButton(String extension) => find.byKey(
  ValueKey('forge.configuration.map.$_fileTypesId.$extension.remove'),
);

Future<void> _settleWrite(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

/// Adds [extension] through the table's field and *Add* (it opens in the
/// default editor until changed).
Future<void> addFileTypeExtension(WidgetTester tester, String extension) async {
  final field = fileTypeNewExtensionField();
  expect(field, findsOneWidget);
  await _showInTile(tester, field);
  await tester.enterText(field, extension);
  await tester.tap(
    find.byKey(const ValueKey('forge.configuration.map.$_fileTypesId.add')),
  );
  await _settleWrite(tester);
}

/// Makes [extension] (`*`: every other one) open in [editorId], as choosing
/// it in the row's editor choice does.
Future<void> setFileTypeEditor(
  WidgetTester tester,
  String extension,
  String editorId,
) async {
  final scope = tester.widget<ForgeConfigurationScope>(
    find.byType(ForgeConfigurationScope).first,
  );
  final setting = ForgeFileTypesConfiguration.associations;
  final current = scope.values.valueOf(setting);
  final problem = await scope.values.set(setting, {
    ...current,
    extension: editorId,
  });
  expect(problem, isNull);
  await _settleWrite(tester);
}

/// Removes [extension]'s row with its remove button.
Future<void> removeFileTypeExtension(
  WidgetTester tester,
  String extension,
) async {
  final button = fileTypeRemoveButton(extension);
  expect(button, findsOneWidget);
  await _showInTile(tester, button);
  await tester.tap(button);
  await _settleWrite(tester);
}

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
Future<void> _showInTile(WidgetTester tester, Finder finder) async {
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

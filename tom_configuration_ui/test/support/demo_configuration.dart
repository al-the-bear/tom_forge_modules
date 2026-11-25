// A fake module with a configuration description of every kind, the kit API
// it registers with, and a test page that arranges the tiles itself.

import 'package:flutter/material.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeShellTheme;

const wrapSetting = ForgeBoolSetting(
  id: 'wrap',
  storage: ForgeSettingStorage('demo.wrap'),
  label: ForgeText('demo.wrap', 'Wrap long lines'),
  help: ForgeText('demo.wrap.help', 'Lines longer than the view wrap.'),
);

const sizeSetting = ForgeIntSetting(
  id: 'size',
  storage: ForgeSettingStorage('demo.size'),
  label: ForgeText('demo.size', 'Tab size'),
  defaultValue: 4,
  min: 1,
  max: 16,
  unit: ForgeText('demo.size.unit', 'spaces'),
);

const fontSizeSetting = ForgeDoubleSetting(
  id: 'fontSize',
  storage: ForgeSettingStorage('demo.text', path: ['fontSize']),
  label: ForgeText('demo.fontSize', 'Font size'),
  defaultValue: 14,
  min: 6,
  max: 48,
  decimals: 1,
);

const themeSetting = ForgeChoiceSetting(
  id: 'theme',
  storage: ForgeSettingStorage('demo.theme'),
  label: ForgeText('demo.theme', 'Theme'),
  defaultValue: 'system',
  choices: [
    ForgeSettingChoice('light', ForgeText('demo.theme.light', 'Light')),
    ForgeSettingChoice('dark', ForgeText('demo.theme.dark', 'Dark')),
    ForgeSettingChoice('system', ForgeText('demo.theme.system', 'System')),
  ],
);

const fontSetting = ForgeStringSetting(
  id: 'font',
  storage: ForgeSettingStorage('demo.text', path: ['fontFamily']),
  label: ForgeText('demo.font', 'Font family'),
  defaultValue: 'monospace',
  allowEmpty: false,
  hint: ForgeText('demo.font.hint', 'e.g. Fira Code'),
);

const languageSetting = ForgeChoiceSetting(
  id: 'language',
  storage: ForgeSettingStorage('demo.language'),
  label: ForgeText('demo.language', 'Language'),
  defaultValue: 'en',
  choices: [
    ForgeSettingChoice('en', ForgeText('demo.language.en', 'English')),
    ForgeSettingChoice('de', ForgeText('demo.language.de', 'German')),
    ForgeSettingChoice('fr', ForgeText('demo.language.fr', 'French')),
    ForgeSettingChoice('it', ForgeText('demo.language.it', 'Italian')),
  ],
);

const notesSetting = ForgeStringSetting(
  id: 'notes',
  storage: ForgeSettingStorage('demo.notes'),
  label: ForgeText('demo.notes', 'Notes'),
  multiline: true,
);

const ignoredSetting = ForgeStringListSetting(
  id: 'ignored',
  storage: ForgeSettingStorage('demo.ignored'),
  label: ForgeText('demo.ignored', 'Ignored folders'),
  defaultValue: ['build'],
);

const featuresSetting = ForgeStringListSetting(
  id: 'features',
  storage: ForgeSettingStorage('demo.features'),
  label: ForgeText('demo.features', 'Features'),
  choices: [
    ForgeSettingChoice('lint', ForgeText('demo.features.lint', 'Lint')),
    ForgeSettingChoice('format', ForgeText('demo.features.format', 'Format')),
  ],
);

const sdkSetting = ForgePathSetting(
  id: 'sdk',
  storage: ForgeSettingStorage('demo.sdk'),
  label: ForgeText('demo.sdk', 'SDK folder'),
  pathKind: ForgePathKind.folder,
);

const accentSetting = ForgeColorSetting(
  id: 'accent',
  storage: ForgeSettingStorage('demo.accent'),
  label: ForgeText('demo.accent', 'Accent colour'),
  defaultValue: 0xFF2196F3,
);

const associationsSetting = ForgeStringMapSetting(
  id: 'associations',
  storage: ForgeSettingStorage('demo.associations'),
  label: ForgeText('demo.associations', 'File types'),
  defaultValue: {'.md': 'markdown'},
  keyLabel: ForgeText('demo.associations.key', 'Extension'),
  valueLabel: ForgeText('demo.associations.value', 'Editor'),
  valueChoices: [
    ForgeSettingChoice('markdown', ForgeText('demo.editor.md', 'Markdown')),
    ForgeSettingChoice('text', ForgeText('demo.editor.text', 'Plain text')),
  ],
);

const editingSection = ForgeSettingsSection(
  id: 'editing',
  title: ForgeText('demo.editing', 'Editing'),
  help: ForgeText('demo.editing.help', 'How the editor treats text.'),
  icon: ForgeIconRef(0xe21a), // Icons.edit
  order: 10,
  settings: [
    wrapSetting,
    sizeSetting,
    fontSizeSetting,
    themeSetting,
    fontSetting,
  ],
);

const filesSection = ForgeSettingsSection(
  id: 'files',
  title: ForgeText('demo.files', 'Files'),
  order: 20,
  settings: [
    languageSetting,
    notesSetting,
    ignoredSetting,
    featuresSetting,
    sdkSetting,
    accentSetting,
    associationsSetting,
  ],
);

const demoDescription = ForgeConfigurationDescription(
  id: 'demo',
  title: ForgeText('demo', 'Demo editor'),
  sections: [filesSection, editingSection],
);

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

/// A module whose component describes its options.
class DemoModule extends ForgeKitModule implements ForgeModuleExtrasProvider {
  DemoModule([this.descriptions = const [demoDescription]]);

  final List<ForgeConfigurationDescription> descriptions;

  @override
  String get displayName => 'Demo';

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
  List<ForgeModuleExtra> get ownExtras => [
    ForgeConfigurationDescriptionsExtra(descriptions),
  ];
}

/// A kit API with [DemoModule] registered, over [store].
DefaultKitApi demoApi(ForgeStateStore store) => DefaultKitApi(
  editorHost: _Host(),
  fileSystem: TomMemoryFileSystem(),
  stateStore: store,
)..registerModule(DemoModule());

/// The test page: it arranges the tiles itself, two columns in a [Wrap].
Widget demoPage(
  List<Widget> tiles, {
  ThemeMode themeMode = ThemeMode.light,
  ForgeConfigurationTileStyle style = const ForgeConfigurationTileStyle(),
  double tileWidth = 380,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  themeMode: themeMode,
  theme: ThemeData(
    brightness: Brightness.light,
    extensions: [ForgeShellTheme.light()],
  ),
  darkTheme: ThemeData(
    brightness: Brightness.dark,
    extensions: [ForgeShellTheme.dark()],
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
        ],
      ),
    ),
  ),
);

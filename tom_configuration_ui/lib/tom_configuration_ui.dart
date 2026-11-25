/// The configuration tiles of the Forge kit.
///
/// Every component with options describes them (`tom_forge_core`'s
/// `ForgeConfigurationDescription`); the kit collects the descriptions and
/// keeps the values through its state-store port
/// (`ForgeConfigurationValues`). This package draws them:
///
/// - **Tiles:** [ForgeConfigurationTile], one per section, always drawn the
///   same ([ForgeConfigurationTileStyle]: spacing, padding, density, header,
///   field family; colours from the theme; icons as constants through a
///   [ForgeConfigurationIconResolver]); [forgeConfigurationTiles] makes
///   the tiles of every section for an application to arrange, and
///   [ForgeConfigurationScope] shares the values, editors, style and path
///   picker with the tiles below it.
/// - **Editors:** one per kind of setting, kept in a
///   [ForgeSettingEditorRegistry] ([ForgeSettingEditorRegistry.standard]: the
///   kinds `tom_forge_core` defines, on `tom_flutter_ui`'s form fields where
///   one fits — [ForgeSettingTomField] — and small native widgets else); a
///   new kind of setting registers its editor.
/// - **Labels:** every label and message is a `ForgeText`, resolved through
///   Tom Core's text resources ([ForgeConfigurationLabels]); the package's own
///   strings are [ForgeConfigurationUiTexts].
/// - **Trail:** [kConfigurationUiDebug] (`debug_mode.md`), prefix `[CU`.
library;

export 'src/configuration_ui_trail.dart';
export 'src/editors/behaviour_editors.dart';
export 'src/editors/color_picker.dart';
export 'src/editors/flow_runner.dart';
export 'src/editors/font_family_editor.dart';
export 'src/editors/hook_widgets.dart';
export 'src/editors/key_binding_table_editor.dart';
export 'src/editors/key_capture.dart';
export 'src/editors/standard_editors.dart';
export 'src/editors/setting_tom_field.dart';
export 'src/editors/value_editors.dart';
export 'src/forge_configuration_icons.dart';
export 'src/forge_configuration_labels.dart';
export 'src/forge_configuration_tile.dart';
export 'src/forge_configuration_tile_style.dart';
export 'src/forge_configuration_ui_texts.dart';
export 'src/forge_setting_editor_registry.dart';

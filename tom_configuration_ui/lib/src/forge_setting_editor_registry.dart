import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgePathSetting, ForgeSetting;

import 'editors/standard_editors.dart';
import 'forge_configuration_tile_style.dart';

/// Asks the application for a path: its file or folder picker, starting at
/// [current]. Answers the path chosen, or null when the user cancelled.
typedef ForgePathPicker =
    Future<String?> Function(ForgePathSetting setting, String current);

/// What an editor is given to edit one setting.
///
/// The editor shows [value] and hands every value the user makes to
/// [onChanged]; the tile validates it, writes it through the values service
/// when it is valid and shows [errorText] when it is not (the editor keeps
/// showing what the user typed until the value changes from outside).
class ForgeSettingEditorRequest {
  const ForgeSettingEditorRequest({
    required this.setting,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.fieldId,
    required this.style,
    this.enabled = true,
    this.errorText,
    this.pickPath,
  });

  /// The setting.
  final ForgeSetting<Object> setting;

  /// The value in effect.
  final Object value;

  /// Takes a value the user made (validated and written by the tile).
  final ValueChanged<Object?> onChanged;

  /// The setting's label, resolved (for semantics; the tile draws it).
  final String label;

  /// An id unique to this setting in the application, for the field.
  final String fieldId;

  /// The tile's style.
  final ForgeConfigurationTileStyle style;

  /// Whether the setting can be changed now.
  final bool enabled;

  /// Why the last value the user made was refused, resolved; null when it
  /// was taken.
  final String? errorText;

  /// The application's path picker, or null when it has none.
  final ForgePathPicker? pickPath;
}

/// Builds the editor of one setting.
typedef ForgeSettingEditorBuilder =
    Widget Function(BuildContext context, ForgeSettingEditorRequest request);

/// The editor of one kind of setting: how it is built, and whether the tile
/// draws it beside the label ([inline], e.g. a switch) or below it.
class ForgeSettingEditor {
  const ForgeSettingEditor(this.builder, {this.inline = false, this.width});

  /// Builds the editor.
  final ForgeSettingEditorBuilder builder;

  /// Whether it goes beside the label instead of below it.
  final bool inline;

  /// The width an [inline] editor is given; null: the width it takes itself
  /// (it must then size itself, as a `Row` with `MainAxisSize.min` does).
  /// `tom_flutter_ui`'s fields fill the width they are given, so an inline
  /// editor built on one names its width.
  final double? width;
}

/// The editors by setting kind (`ForgeSetting.kind`).
///
/// [ForgeSettingEditorRegistry.standard] holds an editor for every kind
/// `tom_forge_core` defines (`ForgeSettingKinds`); a new kind of setting gets
/// its editor with [register], as does an application that wants another
/// editor for a kind.
class ForgeSettingEditorRegistry {
  /// A registry holding [editors].
  ForgeSettingEditorRegistry([Map<String, ForgeSettingEditor>? editors])
    : _editors = {...?editors};

  /// A registry with the standard editors of every kind
  /// (`forgeStandardSettingEditors`).
  factory ForgeSettingEditorRegistry.standard() =>
      ForgeSettingEditorRegistry(forgeStandardSettingEditors());

  final Map<String, ForgeSettingEditor> _editors;

  /// Registers [editor] for [kind], in place of the one it had.
  void register(String kind, ForgeSettingEditor editor) =>
      _editors[kind] = editor;

  /// The editor of [kind], or null.
  ForgeSettingEditor? editorFor(String kind) => _editors[kind];

  /// The kinds with an editor.
  Set<String> get kinds => Set.unmodifiable(_editors.keys);

  /// A copy, to extend without changing this one.
  ForgeSettingEditorRegistry copy() => ForgeSettingEditorRegistry(_editors);
}

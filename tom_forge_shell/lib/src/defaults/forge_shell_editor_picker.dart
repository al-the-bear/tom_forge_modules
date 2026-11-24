import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../components/forge_editor_choice.dart';
import '../services/forge_preferences_service.dart';
import 'default_layout_controller.dart';
import 'default_shell_api.dart';

/// The panel shell's [ForgeEditorPicker]: the kit's model over the shell's
/// modules, its editor types and its preferences, every choice a
/// [ForgeEditorChoice] (so **Open With** can open it in a given middle
/// panel).
///
/// - **Choices:** every module's (by URI and by content type), the editor
///   types of the layout controller ([DefaultLayoutController.editorTypes],
///   opened with [DefaultLayoutController.openFileInEditorType]), then the
///   editors already open on the file that accept it
///   ([DefaultLayoutController.openEditorChoicesFor]) — the ones
///   `openFileWith` offers, plus the editor types.
/// - **Defaults:** by extension, the shell's file-type defaults
///   ([DefaultShellApi.getFileTypeDefaults], what `openFileWith` and the
///   editor routing follow), written to the shell and to its preferences
///   (`ForgePreferencesService.forStore(stateStore)`, `forge.files.typeDefaults`);
///   by content type, the preferences' (`forge.files.contentTypeDefaults`).
///   As for every preference, a default set before the preferences are
///   restored is not stored.
class ForgeShellEditorPicker extends ForgeEditorPicker {
  ForgeShellEditorPicker(this.shell)
    : super(
        modules: () => shell.modules.allKitModules,
        defaults: _ShellEditorDefaults(shell),
      );

  /// The shell the picker offers editors in.
  final DefaultShellApi shell;

  DefaultLayoutController? get _layout {
    final layout = shell.layout;
    return layout is DefaultLayoutController ? layout : null;
  }

  @override
  List<ForgeKitEditorType> get editorTypes => _layout?.editorTypes ?? const [];

  @override
  ForgeKitEditorChoice? choiceForType(ForgeKitEditorType type) {
    final layout = _layout;
    if (layout == null) return null;
    return ForgeEditorChoice(
      id: type.id,
      label: type.label,
      description: type.description.isEmpty ? null : type.description,
      icon: type.icon ?? Icons.description_outlined,
      contentTypes: type.contentTypes,
      open: (uri, {middlePanelIndex}) => unawaited(
        layout.openFileInEditorType(
          uri,
          type.id,
          middlePanelIndex: middlePanelIndex,
        ),
      ),
    );
  }

  @override
  ForgeKitEditorChoice adaptChoice(ForgeKitEditorChoice choice) =>
      _layout?.shellChoiceOf(choice) ?? choice;

  @override
  Future<List<ForgeKitEditorChoice>> moreChoices(ForgeContentItem item) async =>
      await _layout?.openEditorChoicesFor(item.uri) ?? const [];
}

/// The shell's defaults: by extension its file-type defaults (kept in the
/// shell and stored in its preferences), by content type its preferences'.
class _ShellEditorDefaults implements ForgeEditorDefaults {
  _ShellEditorDefaults(this.shell);

  final DefaultShellApi shell;

  ForgePreferencesService get _preferences =>
      ForgePreferencesService.forStore(shell.stateStore);

  @override
  Map<String, String> get fileTypeDefaultEditors => shell.getFileTypeDefaults();

  @override
  void setFileTypeDefaultEditor(String extension, String editorTypeId) {
    shell.setFileTypeDefault(extension, editorTypeId);
    _preferences.setFileTypeDefaultEditor(extension, editorTypeId);
  }

  @override
  void clearFileTypeDefaultEditor(String extension) {
    shell.clearFileTypeDefault(extension);
    _preferences.clearFileTypeDefaultEditor(extension);
  }

  @override
  Map<String, String> get contentTypeDefaultEditors =>
      _preferences.contentTypeDefaultEditors;

  @override
  void setContentTypeDefaultEditor(String contentType, String editorTypeId) {
    _preferences.setContentTypeDefaultEditor(contentType, editorTypeId);
  }

  @override
  void clearContentTypeDefaultEditor(String contentType) {
    _preferences.clearContentTypeDefaultEditor(contentType);
  }

  // The preferences notify when a default they keep changes (by the
  // picker, or by the configuration dialog).
  @override
  void addListener(VoidCallback listener) => _preferences.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _preferences.removeListener(listener);
}

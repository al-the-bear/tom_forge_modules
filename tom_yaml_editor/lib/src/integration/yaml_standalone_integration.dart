import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';

/// Debug flag for YamlStandaloneIntegration.
bool kYamlStandaloneIntegrationDebug = false;

void _log(String message) {
  if (kYamlStandaloneIntegrationDebug) {
    // ignore: avoid_print
    print('[YamlStandaloneIntegration] $message');
  }
}

/// Default settings for standalone YAML editing.
class YamlEditorDefaults {
  YamlEditorDefaults._();

  /// Default monospace font for YAML editing.
  static const String defaultFontFamily = 'monospace';

  /// Default font size.
  static const double defaultFontSize = 13.0;

  /// Default tab size (spaces per indent level).
  static const int defaultTabSize = 2;

  /// Default line height multiplier.
  static const double defaultLineHeight = 1.4;

  /// Default settings instance.
  static const ForgeTextSettings defaultSettings = ForgeTextSettings(
    fontFamily: defaultFontFamily,
    fontSize: defaultFontSize,
    lineHeight: defaultLineHeight,
    tabSize: defaultTabSize,
    insertSpaces: true,
    wordWrap: false,
    showLineNumbers: true,
  );

  /// Creates [ForgeTextSettings] from a [YamlEditorTheme].
  ///
  /// Maps the theme's font settings to the integration's text settings
  /// so that the standalone integration respects the active theme.
  static ForgeTextSettings forgeTextSettingsFrom(YamlEditorTheme theme) {
    return ForgeTextSettings(
      fontFamily: theme.fonts.valueFontFamily,
      fontSize: theme.fonts.valueFontSize,
      lineHeight: theme.fonts.lineHeight,
      tabSize: defaultTabSize,
      insertSpaces: true,
      wordWrap: false,
      showLineNumbers: true,
    );
  }
}

/// Standalone integration for the YAML tree editor.
///
/// Unlike text-based integrations that extend [BaseStandaloneIntegration],
/// this implements [ForgeEditorIntegration] directly because the YAML editor
/// is tree-based — it does not have a single [TextEditingController].
///
/// Bridges the [YamlEditorController]'s undo/redo to the integration
/// interface and registers standard undo/redo action handlers.
///
/// ```dart
/// final integration = YamlStandaloneIntegration(
///   controller: yamlController,
/// );
/// ```
class YamlStandaloneIntegration extends ForgeEditorIntegration
    with StandardActionsMixin {
  /// The YAML editor controller providing document state and undo/redo.
  final YamlEditorController controller;

  ForgeTextSettings _textSettings;
  late final _YamlTextContext _textContext;

  /// Creates a standalone integration for the YAML editor.
  ///
  /// [controller] manages the YAML document and its undo/redo history.
  /// [textSettings] overrides the default monospace font settings.
  YamlStandaloneIntegration({
    required this.controller,
    ForgeTextSettings? textSettings,
  }) : _textSettings = textSettings ?? YamlEditorDefaults.defaultSettings {
    _textContext = _YamlTextContext(controller: controller);
    controller.addListener(_onControllerChanged);
    _registerStandardActions();
    _log('Created YamlStandaloneIntegration');
  }

  void _onControllerChanged() {
    _textContext.notifyChanged();
  }

  void _registerStandardActions() {
    try {
      registerAction(
        StandardEditingActions.undoActionId,
        _doUndo,
        isEnabled: () => controller.canUndo,
      );
      registerAction(
        StandardEditingActions.redoActionId,
        _doRedo,
        isEnabled: () => controller.canRedo,
      );
      _log('Registered ${supportedActions.length} standard actions');
    } catch (e) {
      _log('Error registering standard actions: $e');
    }
  }

  // ── Undo/Redo bridge ───────────────────────────────────────────────────

  /// Whether undo is available (delegates to controller).
  bool get canUndo => controller.canUndo;

  /// Whether redo is available (delegates to controller).
  bool get canRedo => controller.canRedo;

  /// Undo the last edit (delegates to controller).
  void undo() {
    _log('undo');
    controller.undo();
  }

  /// Redo the last undone edit (delegates to controller).
  void redo() {
    _log('redo');
    controller.redo();
  }

  void _doUndo() => undo();
  void _doRedo() => redo();

  // ── ForgeEditorIntegration implementation ──────────────────────────────

  @override
  ForgeTextContext get textContext => _textContext;

  @override
  ForgeTextSettings get textSettings => _textSettings;

  @override
  set textSettings(ForgeTextSettings settings) {
    _log('Text settings updated');
    _textSettings = settings;
  }

  @override
  List<EditorActionDescriptor> get actionDescriptors => [
        ...YamlEditorActions.descriptors,
        // Only undo/redo from standard actions (tree-based, no cut/copy/paste)
        ...StandardEditingActions.descriptors
            .where((d) =>
                d.id == StandardEditingActions.undoActionId ||
                d.id == StandardEditingActions.redoActionId),
      ];

  @override
  List<ForgeAction> get supportedActions => [
        StandardEditingActions.undo(),
        StandardEditingActions.redo(),
      ];

  @override
  ForgeShortcutKey? getShortcutForAction(String actionId) {
    switch (actionId) {
      case StandardEditingActions.undoActionId:
        return StandardEditingActions.undoShortcut;
      case StandardEditingActions.redoActionId:
        return StandardEditingActions.redoShortcut;
      default:
        return null;
    }
  }

  @override
  void requestFocus() {
    _log('requestFocus: no-op for tree editor');
  }

  @override
  bool get hasFocus => false;

  @override
  void setText(String text, {bool addToUndoHistory = true}) {
    _log('setText: ${text.length} chars');
    controller.setYaml(text);
  }

  @override
  void setSelection(TextSelection selection) {
    // Tree-based editor has no text selection.
    _log('setSelection: no-op for tree editor');
  }

  @override
  void insertText(String text) {
    // Tree-based editor cannot insert text at cursor.
    _log('insertText: no-op for tree editor');
  }

  @override
  void addTextChangeListener(TextChangeCallback callback) {
    // The YamlEditorController uses ChangeNotifier; callers should use
    // controller.addListener instead. This is a no-op stub.
    _log('addTextChangeListener: use controller.addListener instead');
  }

  @override
  void removeTextChangeListener(TextChangeCallback callback) {
    _log('removeTextChangeListener: no-op for tree editor');
  }

  @override
  void addSelectionChangeListener(SelectionChangeCallback callback) {
    _log('addSelectionChangeListener: no-op for tree editor');
  }

  @override
  void removeSelectionChangeListener(SelectionChangeCallback callback) {
    _log('removeSelectionChangeListener: no-op for tree editor');
  }

  @override
  void dispose() {
    _log('dispose');
    controller.removeListener(_onControllerChanged);
    _textContext.dispose();
  }
}

/// Text context adapter for the YAML editor.
///
/// Provides the serialized YAML text and undo/redo state from the
/// [YamlEditorController]. Selection is always collapsed at position 0
/// since the tree editor has no text cursor.
class _YamlTextContext implements ForgeTextContext {
  final YamlEditorController controller;
  final StreamController<ForgeTextContext> _contextController =
      StreamController<ForgeTextContext>.broadcast();

  _YamlTextContext({required this.controller});

  @override
  String get text => controller.yamlText;

  @override
  int get cursorOffset => 0;

  @override
  int get currentLine => 1;

  @override
  int get currentColumn => 1;

  @override
  bool get isDirty => controller.isDirtyNotifier.value;

  @override
  bool get canUndo => controller.canUndo;

  @override
  bool get canRedo => controller.canRedo;

  @override
  List<TextSelection> get selections =>
      const [TextSelection.collapsed(offset: 0)];

  @override
  Stream<ForgeTextContext> get onContextChanged => _contextController.stream;

  /// Notifies listeners that context has changed.
  void notifyChanged() => _contextController.add(this);

  /// Closes the stream controller.
  void dispose() => _contextController.close();
}

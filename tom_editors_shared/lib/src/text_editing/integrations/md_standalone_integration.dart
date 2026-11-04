
import '../../forge_bridge/editor_action_descriptor.dart';
import '../md_editor_actions.dart';
import '../standard_editing_actions.dart';
import '../forge_text_settings.dart';
import 'base_standalone_integration.dart';

/// Debug flag for MdStandaloneIntegration.
bool kMdStandaloneIntegrationDebug = false;

void _log(String message) {
  if (kMdStandaloneIntegrationDebug) {
    // ignore: avoid_print
    print('[MdStandaloneIntegration] $message');
  }
}

/// Default font settings for the markdown editor.
class MdEditorDefaults {
  MdEditorDefaults._();

  /// Default proportional font for prose editing.
  static const String defaultFontFamily = 'Segoe UI';

  /// Default monospace font for code blocks.
  static const String defaultMonoFontFamily = 'Cascadia Code';

  /// Default font size.
  static const double defaultFontSize = 14.0;

  /// Default line height multiplier.
  static const double defaultLineHeight = 1.6;

  /// Default tab size (spaces per indent level).
  static const int defaultTabSize = 2;

  /// Default settings instance.
  static const ForgeTextSettings defaultSettings = ForgeTextSettings(
    fontFamily: defaultFontFamily,
    fontSize: defaultFontSize,
    lineHeight: defaultLineHeight,
    tabSize: defaultTabSize,
    insertSpaces: true,
    wordWrap: true,
    showLineNumbers: false,
  );
}

/// Standalone integration for the markdown editor.
///
/// Extends [BaseStandaloneIntegration] with markdown-specific defaults and
/// disables automatic undo tracking (the [MdEditorController] manages its
/// own history of `MdEditOperation`s on `tom_undo`'s `TomUndoStack`).
///
/// After creation, the MdEditor widget registers its own action handlers
/// for undo/redo, save, search, and markdown-specific operations.
///
/// ```dart
/// final integration = MdStandaloneIntegration(
///   controller: textController,
///   focusNode: focusNode,
/// );
/// ```
class MdStandaloneIntegration extends BaseStandaloneIntegration {
  /// Creates a standalone integration for the markdown editor.
  ///
  /// [controller] and [focusNode] are the text controller and focus node
  /// from the MdRawTextEditor widget.
  ///
  /// [textSettings] overrides the default markdown font settings.
  ///
  /// Auto undo tracking is disabled by default; the MdEditorController
  /// manages its own undo history.
  MdStandaloneIntegration({
    required super.controller,
    required super.focusNode,
    ForgeTextSettings? textSettings,
  }) : super(
          textSettings: textSettings ?? MdEditorDefaults.defaultSettings,
          enableAutoUndoTracking: false,
        ) {
    _log('Created MdStandaloneIntegration');
  }

  @override
  List<EditorActionDescriptor> get actionDescriptors => [
        ...MdEditorActions.descriptors,
        ...StandardEditingActions.descriptors,
      ];
}

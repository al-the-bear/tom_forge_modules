
import '../../forge_bridge/editor_action_descriptor.dart';
import '../dart_editor_actions.dart';
import '../standard_editing_actions.dart';
import '../forge_text_settings.dart';
import 'base_standalone_integration.dart';

/// Debug flag for DartStandaloneIntegration.
bool kDartStandaloneIntegrationDebug = false;

void _log(String message) {
  if (kDartStandaloneIntegrationDebug) {
    // ignore: avoid_print
    print('[DartStandaloneIntegration] $message');
  }
}

/// Default font settings for the Dart code editor.
class DartEditorDefaults {
  DartEditorDefaults._();

  /// Default monospace font for code editing.
  static const String defaultFontFamily = 'JetBrains Mono';

  /// Default font size for code.
  static const double defaultFontSize = 13.0;

  /// Default line height multiplier.
  static const double defaultLineHeight = 1.5;

  /// Default tab size (spaces per indent level).
  static const int defaultTabSize = 2;

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
}

/// Standalone integration for the Dart code editor.
///
/// Extends [BaseStandaloneIntegration] with Dart-specific defaults and
/// disables automatic undo tracking (the Dart editor manages its own
/// debounced undo mechanism).
///
/// After creation, the Dart editor should register its own action handlers
/// for undo/redo and Dart-specific operations.
///
/// ```dart
/// final integration = DartStandaloneIntegration(
///   controller: textController,
///   focusNode: focusNode,
/// );
///
/// // Register Dart-specific actions from the editor
/// integration.registerAction(
///   DartEditorActions.triggerCompletionActionId,
///   _triggerCompletion,
///   isEnabled: () => settings.autoCompleteEnabled,
/// );
/// ```
class DartStandaloneIntegration extends BaseStandaloneIntegration {
  /// Creates a standalone integration for the Dart editor.
  ///
  /// [controller] and [focusNode] are the text controller and focus node
  /// from the DartCodeEditor widget.
  ///
  /// [textSettings] overrides the default Dart font settings.
  ///
  /// Auto undo tracking is disabled by default; the Dart editor uses
  /// debounced undo saving for better user experience.
  DartStandaloneIntegration({
    required super.controller,
    required super.focusNode,
    ForgeTextSettings? textSettings,
    super.maxUndoStackSize,
  }) : super(
          textSettings: textSettings ?? DartEditorDefaults.defaultSettings,
          enableAutoUndoTracking: false,
        ) {
    _log('Created DartStandaloneIntegration');
  }

  @override
  List<EditorActionDescriptor> get actionDescriptors => [
        ...DartEditorActions.descriptors,
        ...StandardEditingActions.descriptors,
      ];
}

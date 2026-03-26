import 'package:flutter/widgets.dart';

import '../md_editor_actions.dart';
import '../forge_text_settings.dart';
import '../standard_editing_actions.dart';
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
/// own [UndoHistory<MdEditOperation>] stack).
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
    super.maxUndoStackSize,
  }) : super(
          textSettings: textSettings ?? MdEditorDefaults.defaultSettings,
          enableAutoUndoTracking: false,
        ) {
    _log('Created MdStandaloneIntegration');
  }

  /// Builds a map of all registered action shortcuts plus alternatives.
  ///
  /// Includes both the primary shortcuts from registered [ForgeAction]s and
  /// any alternative shortcuts defined in [MdEditorActions].
  ///
  /// Returns a map from [SingleActivator] to action ID, suitable for
  /// Flutter's [Shortcuts] widget.
  Map<SingleActivator, String> buildShortcutMap() {
    final map = <SingleActivator, String>{};

    try {
      // Primary shortcuts from registered actions
      for (final action in supportedActions) {
        final key = getShortcutForAction(action.id);
        if (key != null) {
          map[key.toActivator()] = action.id;
        }
      }

      // Add alternative shortcuts
      for (final entry in MdEditorActions.alternativeShortcuts.entries) {
        final actionId = entry.key;
        for (final altKey in entry.value) {
          map[altKey.toActivator()] = actionId;
        }
      }

      // Add alternative redo shortcut (Ctrl+Y)
      map[StandardEditingActions.redoAltShortcut.toActivator()] =
          StandardEditingActions.redoActionId;

      _log('Built shortcut map with ${map.length} entries');
    } catch (e) {
      _log('Error building shortcut map: $e');
    }

    return map;
  }
}

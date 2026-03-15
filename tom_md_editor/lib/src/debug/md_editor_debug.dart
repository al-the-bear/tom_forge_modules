import 'package:tom_editors_shared/tom_editors_shared.dart';

/// Debug control for the markdown editor.
///
/// Set [enabled] to `true` to activate debug logging.
/// ```dart
/// MdEditorDebug.enabled = true;
/// ```
class MdEditorDebug {
  MdEditorDebug._();

  /// Global switch for debug output.
  static bool enabled = false;

  /// Logger instance shared across all md editor components.
  static final EditorLogger logger = EditorLogger(
    'MdEditor',
    () => enabled,
  );
}

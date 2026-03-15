import 'dart:developer' as dev;

/// Shared debug logging utility for all editor packages.
///
/// Each package should create a static instance and expose a static
/// [enabled] flag that users can toggle from outside.
///
/// ```dart
/// class MdEditorDebug {
///   static bool enabled = false;
///   static final logger = EditorLogger('MdEditor', () => enabled);
/// }
/// ```
class EditorLogger {
  EditorLogger(this.tag, this._isEnabled);

  final String tag;
  final bool Function() _isEnabled;

  /// Log an informational message.
  void info(String message) {
    if (!_isEnabled()) return;
    dev.log('[$tag] $message', name: tag);
  }

  /// Log a warning message.
  void warn(String message) {
    if (!_isEnabled()) return;
    dev.log('[$tag] ⚠ $message', name: tag, level: 900);
  }

  /// Log an error with optional stack trace.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    // Errors are always logged regardless of enabled flag.
    dev.log(
      '[$tag] ✖ $message',
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

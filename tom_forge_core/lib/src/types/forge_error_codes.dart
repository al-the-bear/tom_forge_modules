/// Standardized diagnostic error codes for the Forge Shell.
///
/// Each code belongs to a category (prefix) with a three-digit number:
/// - `FS*` — File System errors
/// - `MD*` — Module lifecycle errors
/// - `CF*` — Configuration errors
/// - `ED*` — Editor errors
/// - `SH*` — Shortcut conflicts
/// - `UI*` — UI/layout errors
abstract final class ForgeErrorCodes {
  // ---------------------------------------------------------------------------
  // FS — File System
  // ---------------------------------------------------------------------------

  /// File not found: {uri}
  static const String fsFileNotFound = 'FS001';

  /// Permission denied: {uri}
  static const String fsPermissionDenied = 'FS002';

  /// Disk full
  static const String fsDiskFull = 'FS003';

  /// File modified externally: {uri}
  static const String fsExternallyModified = 'FS004';

  /// Too many file watchers
  static const String fsTooManyWatchers = 'FS005';

  // ---------------------------------------------------------------------------
  // MD — Module
  // ---------------------------------------------------------------------------

  /// Module failed to activate: {module}
  static const String mdActivationFailed = 'MD001';

  /// Module dependency not found: {dep}
  static const String mdDependencyNotFound = 'MD002';

  /// Module threw exception: {module}
  static const String mdException = 'MD003';

  // ---------------------------------------------------------------------------
  // CF — Configuration
  // ---------------------------------------------------------------------------

  /// Configuration parse error
  static const String cfParseError = 'CF001';

  /// Invalid configuration value: {key}
  static const String cfInvalidValue = 'CF002';

  /// Configuration schema mismatch
  static const String cfSchemaMismatch = 'CF003';

  // ---------------------------------------------------------------------------
  // ED — Editor
  // ---------------------------------------------------------------------------

  /// Editor failed to load: {uri}
  static const String edLoadFailed = 'ED001';

  /// No editor available for: {uri}
  static const String edNoEditor = 'ED002';

  /// Editor crashed: {editor}
  static const String edCrashed = 'ED003';

  // ---------------------------------------------------------------------------
  // SH — Shortcut
  // ---------------------------------------------------------------------------

  /// Shortcut conflict: {shortcut}
  static const String shConflict = 'SH001';

  /// Invalid shortcut: {shortcut}
  static const String shInvalid = 'SH002';

  // ---------------------------------------------------------------------------
  // UI — UI/Layout
  // ---------------------------------------------------------------------------

  /// Layout restoration failed
  static const String uiLayoutRestoreFailed = 'UI001';

  /// Drag operation failed
  static const String uiDragFailed = 'UI002';

  /// Returns the category name for a given error code prefix.
  static String categoryFor(String code) {
    if (code.startsWith('FS')) return 'File System';
    if (code.startsWith('MD')) return 'Module';
    if (code.startsWith('CF')) return 'Config';
    if (code.startsWith('ED')) return 'Editor';
    if (code.startsWith('SH')) return 'Shortcut';
    if (code.startsWith('UI')) return 'UI';
    return 'Unknown';
  }
}

/// Severity levels for forge diagnostics.
enum ForgeSeverity {
  /// A hard error — the document or operation has failed.
  error,

  /// A warning — something may be incorrect but is not fatal.
  warning,

  /// An informational message — helpful but not a problem.
  info,

  /// A hint — a suggestion for improvement.
  hint,
}

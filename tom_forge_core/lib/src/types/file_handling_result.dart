/// Result of a file-handling query on an editor.
enum FileHandlingResult {
  /// The editor accepts this file.
  accept,

  /// The editor cannot handle this file.
  reject,

  /// The editor needs to inspect the file content before deciding
  /// (Phase 1 only — triggers a Phase 2 call).
  inspect,
}

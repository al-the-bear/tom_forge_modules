/// Severity of a configuration issue surfaced by the validator.
enum ConfigSeverity {
  /// A violation that makes the configuration invalid (blocks the registry).
  error,

  /// A non-fatal concern (e.g. a likely-unintended value).
  warning,
}

/// A single problem found while validating a `tom.website-editor.yaml`
/// document, carrying the location and a human-readable message.
///
/// [path] is a dotted/bracketed location into the document
/// (e.g. `websites[0].paths.websiteRoot`) so the config editor (§6) can place
/// the diagnostic inline.
class ConfigIssue {
  const ConfigIssue({
    required this.path,
    required this.message,
    this.severity = ConfigSeverity.error,
  });

  /// Document location, e.g. `websites[0].commands`.
  final String path;

  /// Human-readable description of the problem.
  final String message;

  /// How serious the issue is.
  final ConfigSeverity severity;

  @override
  String toString() => '[${severity.name}] $path: $message';
}

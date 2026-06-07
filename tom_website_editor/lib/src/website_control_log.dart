/// Severity of a [WebsiteLogEntry] in the control-panel message log (§5).
enum WebsiteLogLevel {
  /// Normal progress (stdout, command echo, exit `0`).
  info,

  /// Diagnostics that are not fatal (stderr lines).
  warning,

  /// A real failure or a usage/config bug (exit `1` / `2`, resolution errors).
  error,
}

/// One line in the control-panel message log (§5).
///
/// Entries are immutable values; the controller owns the list and re-emits it on
/// change. [pinned] marks the latest errors so the view can keep them visible
/// even when the user filters the log.
class WebsiteLogEntry {
  const WebsiteLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.pinned = false,
  });

  /// Severity of this entry.
  final WebsiteLogLevel level;

  /// The human-readable text.
  final String message;

  /// When the entry was recorded.
  final DateTime timestamp;

  /// Whether this entry is pinned (latest errors stay visible under filtering).
  final bool pinned;
}

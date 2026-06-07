/// Thrown when a `{placeholder}` cannot be resolved (§3): an unknown token, an
/// unset `{env:VAR}`, a resolution cycle, or exceeding the max expansion depth.
///
/// Carries the offending [token] and the [location] in the configuration where
/// the failing template lives, so the message points at a concrete spot.
class PlaceholderException implements Exception {
  const PlaceholderException({
    required this.token,
    required this.location,
    required this.message,
  });

  /// The placeholder name that failed, e.g. `websiteRoot` or `env:MY_TOKEN`.
  /// Empty for failures not tied to a single token (e.g. max-depth).
  final String token;

  /// Caller-supplied location of the failing template, e.g. `websites[0].cwd`.
  final String location;

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => 'PlaceholderException: $message (at $location)';
}

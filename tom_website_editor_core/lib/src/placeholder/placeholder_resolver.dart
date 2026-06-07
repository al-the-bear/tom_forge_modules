import 'dart:io' show Platform;

import '../model/website_editor_config.dart';
import 'placeholder_exception.dart';

/// Matches a single `{token}` placeholder. The token may not contain braces,
/// so nested templates are expanded one layer at a time via recursion.
final RegExp _placeholderToken = RegExp(r'\{([^{}]+)\}');

/// Resolves `{placeholder}` templates against a layered set of values (§3).
///
/// Resolution priority, highest first:
///   1. [websiteScope] — per-website keys (paths, preview, cwd, id),
///   2. [defaults] — `defaults.placeholders` from the config,
///   3. [builtins] — host-provided values (`{port}`, `{browser}`, …).
///
/// A handful of tokens are computed rather than looked up: `{home}` and a
/// leading `~` expand to [homeDir]; `{env:VAR}` reads [environment]; `{date}`
/// and `{time}` format [clock]. Values are expanded recursively, with cycle
/// detection and a [maxDepth] guard. An unknown token, an unset `{env:VAR}`, a
/// cycle, or exceeding [maxDepth] throws a [PlaceholderException].
class PlaceholderResolver {
  PlaceholderResolver({
    required this.websiteScope,
    required this.defaults,
    this.builtins = const {},
    this.maxDepth = 32,
    Map<String, String>? environment,
    String? homeDir,
    DateTime Function()? clock,
  })  : environment = environment ?? Platform.environment,
        homeDir = homeDir ?? _defaultHomeDir(),
        clock = clock ?? DateTime.now;

  /// Builds a resolver whose scope is derived from a loaded [website] entry:
  /// its `paths`, `preview`, `cwd` (defaulting to `{websiteRoot}`), and `id`,
  /// layered over the config's `defaults.placeholders`.
  factory PlaceholderResolver.forWebsite(
    WebsiteEditorConfig config,
    WebsiteEntry website, {
    Map<String, String> builtins = const {},
    Map<String, String>? environment,
    String? homeDir,
    int maxDepth = 32,
    DateTime Function()? clock,
  }) {
    final scope = <String, String>{
      ...website.paths,
      ...website.preview,
      'cwd': website.cwd ?? '{websiteRoot}',
      'id': website.id,
    };
    return PlaceholderResolver(
      websiteScope: scope,
      defaults: config.defaults.placeholders,
      builtins: builtins,
      environment: environment,
      homeDir: homeDir,
      maxDepth: maxDepth,
      clock: clock,
    );
  }

  /// Per-website placeholder values (priority tier 1).
  final Map<String, String> websiteScope;

  /// Workspace-wide placeholder values (priority tier 2).
  final Map<String, String> defaults;

  /// Host-provided built-in values such as `{port}` and `{browser}` (tier 3).
  final Map<String, String> builtins;

  /// Environment used to resolve `{env:VAR}` tokens.
  final Map<String, String> environment;

  /// Home directory for `{home}` and leading-`~` expansion.
  final String homeDir;

  /// Maximum recursive expansion depth before failing (cycle backstop).
  final int maxDepth;

  /// Clock used to format `{date}` and `{time}`.
  final DateTime Function() clock;

  /// Expands every placeholder in [template].
  ///
  /// [location] is echoed back in any [PlaceholderException] so the message
  /// points at the configuration site that owns the failing template.
  String resolve(String template, {String? location}) =>
      _resolve(template, location ?? 'config', const <String>{}, 0);

  String _resolve(
    String template,
    String location,
    Set<String> active,
    int depth,
  ) {
    if (depth > maxDepth) {
      throw PlaceholderException(
        token: '',
        location: location,
        message: 'max expansion depth ($maxDepth) exceeded',
      );
    }
    final expanded = template.replaceAllMapped(
      _placeholderToken,
      (match) => _lookup(match.group(1)!, location, active, depth),
    );
    return _expandLeadingTilde(expanded);
  }

  String _lookup(String name, String location, Set<String> active, int depth) {
    if (name == 'home') return homeDir;
    if (name.startsWith('env:')) return _resolveEnv(name, location);
    if (name == 'date') return _formatDate(clock());
    if (name == 'time') return _formatTime(clock());

    if (active.contains(name)) {
      throw PlaceholderException(
        token: name,
        location: location,
        message: 'placeholder resolution cycle detected at "$name"',
      );
    }
    final raw = websiteScope[name] ?? defaults[name] ?? builtins[name];
    if (raw == null) {
      throw PlaceholderException(
        token: name,
        location: location,
        message: 'unknown placeholder "$name"',
      );
    }
    return _resolve(raw, location, {...active, name}, depth + 1);
  }

  String _resolveEnv(String token, String location) {
    final varName = token.substring('env:'.length);
    final value = environment[varName];
    if (value == null) {
      throw PlaceholderException(
        token: token,
        location: location,
        message: 'environment variable "$varName" is not set',
      );
    }
    return value;
  }

  String _expandLeadingTilde(String value) {
    if (value == '~') return homeDir;
    if (value.startsWith('~/')) return '$homeDir${value.substring(1)}';
    return value;
  }

  static String _defaultHomeDir() {
    final env = Platform.environment;
    return env['HOME'] ?? env['USERPROFILE'] ?? '';
  }

  static String _formatDate(DateTime d) =>
      '${_pad(d.year, 4)}-${_pad(d.month, 2)}-${_pad(d.day, 2)}';

  static String _formatTime(DateTime d) =>
      '${_pad(d.hour, 2)}:${_pad(d.minute, 2)}:${_pad(d.second, 2)}';

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}

/// Default argv prefix used to execute command templates when a config does
/// not specify `defaults.shell`.
const List<String> kDefaultShell = ['bash', '-lc'];

/// An immutable, validated `tom.website-editor.yaml` document (§2).
class WebsiteEditorConfig {
  const WebsiteEditorConfig({
    required this.version,
    required this.defaults,
    required this.websites,
  });

  /// Config format version (currently always 1).
  final int version;

  /// Shared defaults (shell, placeholders).
  final ConfigDefaults defaults;

  /// The registered websites, in document order.
  final List<WebsiteEntry> websites;

  /// Returns the website with [id], or `null` if none is registered.
  WebsiteEntry? websiteById(String id) {
    for (final website in websites) {
      if (website.id == id) return website;
    }
    return null;
  }
}

/// The `defaults:` block.
class ConfigDefaults {
  const ConfigDefaults({
    this.shell = kDefaultShell,
    this.placeholders = const {},
  });

  /// argv prefix for executing command templates.
  final List<String> shell;

  /// Workspace-wide placeholder values (§3 priority tier 2).
  final Map<String, String> placeholders;
}

/// One `websites:` entry.
class WebsiteEntry {
  const WebsiteEntry({
    required this.id,
    required this.paths,
    this.label,
    this.preview = const {},
    this.cwd,
    this.commands = const {},
  });

  /// Unique website identifier.
  final String id;

  /// Optional human-readable label for the selector.
  final String? label;

  /// Filesystem locations by leaf name (e.g. `websiteRoot`), raw templates.
  final Map<String, String> paths;

  /// Preview URLs by leaf name (e.g. `devUrl`), raw templates.
  final Map<String, String> preview;

  /// Working directory template; falls back to `{websiteRoot}` when null.
  final String? cwd;

  /// Action name → external command template (§7 contract).
  final Map<String, String> commands;
}

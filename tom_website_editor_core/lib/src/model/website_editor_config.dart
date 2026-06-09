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
    this.content,
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

  /// Content-browser configuration (§6a), or `null` when this website opts out
  /// (in which case the content browser is disabled for it).
  final WebsiteContentConfig? content;
}

/// The per-website `content:` block (§6a) — where the data-model files live and
/// which fields are hand-editable. When absent the content browser is disabled.
///
/// All paths are raw templates: [dir] is placeholder-expanded, and [components]
/// / [site] / [pages] are resolved relative to the expanded [dir].
class WebsiteContentConfig {
  const WebsiteContentConfig({
    required this.dir,
    this.components = kDefaultContentComponents,
    this.copy = kDefaultContentCopy,
    this.areas = kDefaultContentAreas,
    this.site = kDefaultContentSite,
    this.pages = kDefaultContentPages,
    this.editableFields = kDefaultEditableFields,
    this.manualPin = kDefaultManualPin,
  });

  /// Root of the website's content tree (placeholder-expanded).
  final String dir;

  /// Glob (relative to [dir]) for catalog records: component → module →
  /// optional submodule.
  final String components;

  /// Glob (relative to [dir]) for editorial copy — one Markdown file per
  /// component/module/submodule/home whose front-matter carries the
  /// hand-editable fields and whose body is the overview (website spec §16).
  final String copy;

  /// Glob (relative to [dir]) for auto-discovered area definitions
  /// (website spec §17).
  final String areas;

  /// Site-level copy file, relative to [dir].
  final String site;

  /// Glob (relative to [dir]) for standalone pages with override/managed
  /// regions.
  final String pages;

  /// Curated field names that are hand-editable; every other field is managed
  /// (read-only) unless it carries the [manualPin].
  final List<String> editableFields;

  /// The YAML comment that pins a managed field so manual edits survive
  /// regeneration (e.g. `# @manual`).
  final String manualPin;
}

/// Default [WebsiteContentConfig.components] glob.
const String kDefaultContentComponents = 'components/*.yaml';

/// Default [WebsiteContentConfig.copy] glob (website spec §16).
const String kDefaultContentCopy = 'copy/*.md';

/// Default [WebsiteContentConfig.areas] glob (website spec §17).
const String kDefaultContentAreas = 'areas/*.md';

/// Default [WebsiteContentConfig.site] file.
const String kDefaultContentSite = 'site.yaml';

/// Default [WebsiteContentConfig.pages] glob.
const String kDefaultContentPages = 'pages/*.md';

/// Default [WebsiteContentConfig.editableFields] (§2 / §6a curated copy).
///
/// These are the unsuffixed front-matter keys of the website §16 external copy
/// files (`content/copy/*.md`) — the overview is the Markdown body, not an
/// `overview-md` front-matter key. (Earlier revisions listed the now-defunct
/// inline `-md` record fields `summary-md`/`overview-md`; see forge web todo 14.)
const List<String> kDefaultEditableFields = [
  'tagline',
  'summary',
  'enables',
];

/// Default [WebsiteContentConfig.manualPin].
const String kDefaultManualPin = '# @manual';

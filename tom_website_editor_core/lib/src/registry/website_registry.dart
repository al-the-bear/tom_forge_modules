import '../config/config_issue.dart';
import '../config/config_loader.dart';
import '../model/website_editor_config.dart';

/// Outcome of building a [WebsiteRegistry] from YAML source.
class WebsiteRegistryLoad {
  const WebsiteRegistryLoad({required this.registry, required this.issues});

  /// The built registry, or `null` when the source was invalid.
  final WebsiteRegistry? registry;

  /// Every issue found while parsing/validating the source.
  final List<ConfigIssue> issues;

  /// `true` when a registry was built (no error-severity issues).
  bool get isValid => registry != null;
}

/// Outcome of [WebsiteRegistry.reload].
class WebsiteRegistryReload {
  const WebsiteRegistryReload({required this.applied, required this.issues});

  /// `true` when the new config replaced the previous (last-good) one.
  /// `false` means the source was invalid and the registry is unchanged.
  final bool applied;

  /// Every issue found while parsing/validating the new source.
  final List<ConfigIssue> issues;
}

/// Holds the loaded `tom.website-editor.yaml` and the active-website selection
/// that drives every editor view (§4), and owns the reload contract (§6).
///
/// A registry can only be constructed from a *valid* config (see [load]); the
/// website list is therefore guaranteed non-empty. Reloading from invalid
/// source is rejected and leaves the last-good registry in place.
class WebsiteRegistry {
  WebsiteRegistry._(this._config) : _activeId = _config.websites.first.id;

  WebsiteEditorConfig _config;
  String _activeId;

  /// Builds a registry from [yamlSource]. The returned [WebsiteRegistryLoad]
  /// carries a `null` registry (and the issues) when the source is invalid.
  static WebsiteRegistryLoad load(
    String yamlSource, {
    String source = 'tom.website-editor.yaml',
  }) {
    final result = loadWebsiteEditorConfig(yamlSource, source: source);
    final config = result.config;
    return WebsiteRegistryLoad(
      registry: config == null ? null : WebsiteRegistry._(config),
      issues: result.issues,
    );
  }

  /// The current, valid config.
  WebsiteEditorConfig get config => _config;

  /// The registered websites, in document order (never empty).
  List<WebsiteEntry> get websites => _config.websites;

  /// The id of the active website.
  String get activeWebsiteId => _activeId;

  /// The active website entry.
  WebsiteEntry get activeWebsite => _config.websiteById(_activeId)!;

  /// Makes the website with [id] active.
  ///
  /// Throws [ArgumentError] when no website with that id is registered — the
  /// caller (e.g. the config-panel picker) is expected to offer only known ids.
  void selectWebsite(String id) {
    if (_config.websiteById(id) == null) {
      throw ArgumentError.value(
          id, 'id', 'no website with this id is registered');
    }
    _activeId = id;
  }

  /// Reloads the registry from [yamlSource].
  ///
  /// On success the config is replaced and the active selection is preserved
  /// when its id still exists (otherwise it resets to the first website). On
  /// failure the last-good config and selection are kept and `applied` is
  /// `false`.
  WebsiteRegistryReload reload(
    String yamlSource, {
    String source = 'tom.website-editor.yaml',
  }) {
    final result = loadWebsiteEditorConfig(yamlSource, source: source);
    final config = result.config;
    if (config == null) {
      return WebsiteRegistryReload(applied: false, issues: result.issues);
    }
    _config = config;
    if (_config.websiteById(_activeId) == null) {
      _activeId = _config.websites.first.id;
    }
    return WebsiteRegistryReload(applied: true, issues: result.issues);
  }
}

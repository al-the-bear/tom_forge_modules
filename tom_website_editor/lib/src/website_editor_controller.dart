import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

/// Reads the current `tom.website-editor.yaml` source text.
///
/// Injected so the controller can be exercised in tests without a live forge
/// shell — the module wires it to `ForgeShellApi.fileSystem.read(configUri)`.
typedef WebsiteConfigReader = Future<String> Function();

/// Owns the [WebsiteRegistry] and surfaces the active-website selection and the
/// reload contract to the UI (§9.2).
///
/// The registry itself enforces the load/select/reload semantics (§6); this
/// controller adds the async config-source plumbing and change notifications so
/// the config panel can rebuild. On an invalid reload the last-good registry is
/// kept and the new issues are exposed for display.
class WebsiteEditorController extends ChangeNotifier {
  WebsiteEditorController({required WebsiteConfigReader configReader})
      : _configReader = configReader;

  final WebsiteConfigReader _configReader;

  WebsiteRegistry? _registry;
  List<ConfigIssue> _issues = const [];
  bool _isLoading = false;

  /// The active registry, or `null` until a valid config has been loaded.
  WebsiteRegistry? get registry => _registry;

  /// Issues from the most recent load/reload (errors and warnings).
  List<ConfigIssue> get issues => _issues;

  /// `true` while a load/reload is in flight.
  bool get isLoading => _isLoading;

  /// `true` once a valid registry has been built.
  bool get isLoaded => _registry != null;

  /// The registered websites, or empty until loaded.
  List<WebsiteEntry> get websites => _registry?.websites ?? const [];

  /// The active website id, or `null` until loaded.
  String? get activeWebsiteId => _registry?.activeWebsiteId;

  /// Builds the registry from the current config source.
  ///
  /// Returns `true` when a valid registry was built. On failure the issues are
  /// exposed and [isLoaded] stays `false`.
  Future<bool> load() async {
    _setLoading(true);
    try {
      final source = await _configReader();
      final result = WebsiteRegistry.load(source);
      _issues = result.issues;
      if (result.isValid) {
        _registry = result.registry;
      }
      return result.isValid;
    } finally {
      _setLoading(false);
    }
  }

  /// Reloads the config from source (§6 "Save → reload").
  ///
  /// On valid source the registry is replaced (active selection preserved when
  /// it still exists). On invalid source the last-good registry is kept and the
  /// new issues are exposed. Falls back to [load] when nothing is loaded yet.
  /// Returns `true` when the new config was applied.
  Future<bool> reload() async {
    final current = _registry;
    if (current == null) return load();
    _setLoading(true);
    try {
      final source = await _configReader();
      final outcome = current.reload(source);
      _issues = outcome.issues;
      return outcome.applied;
    } finally {
      _setLoading(false);
    }
  }

  /// Makes the website with [id] active and notifies listeners.
  ///
  /// The caller (the config-panel picker) offers only registered ids, so an
  /// unknown id is a programming error and surfaces as an [ArgumentError] from
  /// the registry.
  void selectWebsite(String id) {
    final registry = _registry;
    if (registry == null) return;
    registry.selectWebsite(id);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

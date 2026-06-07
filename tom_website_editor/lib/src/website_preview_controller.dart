import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import 'website_editor_controller.dart';

/// Which preview target the view shows for the active website (§4).
enum WebsitePreviewSource {
  /// The running dev server (`preview.devUrl`).
  devUrl,

  /// The built static index (`preview.builtIndex`, typically a `file://` URL).
  builtIndex,
}

/// Opens [url] in the host's external browser. Injected so the controller can
/// be exercised in tests without launching a real browser.
typedef ExternalUrlOpener = Future<bool> Function(Uri url);

/// The `preview:` map key resolved for each [WebsitePreviewSource].
String _sourceKey(WebsitePreviewSource source) => switch (source) {
      WebsitePreviewSource.devUrl => 'devUrl',
      WebsitePreviewSource.builtIndex => 'builtIndex',
    };

/// Drives the [WebsitePreviewView]: resolves the active website's preview URL,
/// toggles between dev-server and built-index sources, exposes a reload token
/// for forcing a webview refresh, and opens the URL in an external browser (§4).
///
/// It wraps the shared [WebsiteEditorController] (website selection / reload
/// live there) and recomputes the resolved URL whenever the editor changes. URL
/// resolution is delegated to [PlaceholderResolver]; a resolution failure is
/// surfaced via [resolveError] (with the offending token and location) rather
/// than silently producing a blank preview.
class WebsitePreviewController extends ChangeNotifier {
  WebsitePreviewController({
    required WebsiteEditorController editor,
    ExternalUrlOpener? externalOpener,
    Map<String, String> builtins = const {},
    Map<String, String>? environment,
    String? homeDir,
    DateTime Function()? clock,
  })  : _editor = editor,
        _externalOpener = externalOpener ?? _launchInExternalBrowser,
        _builtins = builtins,
        _environment = environment,
        _homeDir = homeDir,
        _clock = clock {
    _editor.addListener(_onEditorChanged);
    _recompute();
  }

  final WebsiteEditorController _editor;
  final ExternalUrlOpener _externalOpener;
  final Map<String, String> _builtins;
  final Map<String, String>? _environment;
  final String? _homeDir;
  final DateTime Function()? _clock;

  WebsitePreviewSource _source = WebsitePreviewSource.devUrl;
  int _reloadToken = 0;

  String? _previewUrl;
  PlaceholderException? _resolveError;

  /// The currently selected preview source.
  WebsitePreviewSource get source => _source;

  /// The resolved preview URL for the active website and [source], or `null`
  /// when no website is loaded, the source key is absent, or resolution failed
  /// (see [resolveError]).
  String? get previewUrl => _previewUrl;

  /// The placeholder failure from the last resolution attempt, or `null` when
  /// the URL resolved (or no template was present).
  PlaceholderException? get resolveError => _resolveError;

  /// Monotonic token bumped by [refresh]; the view rebuilds its webview when it
  /// changes to force a reload of the same URL.
  int get reloadToken => _reloadToken;

  /// The active website id, or `null` until the editor has loaded.
  String? get activeWebsiteId => _editor.activeWebsiteId;

  /// The registered websites (empty until the editor has loaded).
  List<WebsiteEntry> get websites => _editor.websites;

  /// Switches the preview source and recomputes the URL.
  void setSource(WebsitePreviewSource source) {
    if (_source == source) return;
    _source = source;
    _recompute();
    notifyListeners();
  }

  /// Makes [id] the active website (delegates to the shared editor, which
  /// notifies back into [_onEditorChanged]).
  void selectWebsite(String id) => _editor.selectWebsite(id);

  /// Forces the view to reload the current URL.
  void refresh() {
    _reloadToken++;
    notifyListeners();
  }

  /// Opens the resolved [previewUrl] in the external browser via the injected
  /// opener. Returns `false` without calling the opener when there is no URL.
  Future<bool> openInExternalBrowser() async {
    final url = _previewUrl;
    if (url == null) return false;
    return _externalOpener(Uri.parse(url));
  }

  void _onEditorChanged() {
    _recompute();
    notifyListeners();
  }

  /// Recomputes [_previewUrl] / [_resolveError] from the editor's active
  /// website. Pure: only mutates the cached fields, never notifies.
  void _recompute() {
    _previewUrl = null;
    _resolveError = null;

    final registry = _editor.registry;
    if (registry == null) return;

    final website = registry.activeWebsite;
    final template = website.preview[_sourceKey(_source)];
    if (template == null) return;

    final resolver = PlaceholderResolver.forWebsite(
      registry.config,
      website,
      builtins: _builtins,
      environment: _environment,
      homeDir: _homeDir,
      clock: _clock,
    );
    try {
      _previewUrl = resolver.resolve(
        template,
        location: 'websites.${website.id}.preview.${_sourceKey(_source)}',
      );
    } on PlaceholderException catch (e) {
      _resolveError = e;
    }
  }

  @override
  void dispose() {
    _editor.removeListener(_onEditorChanged);
    super.dispose();
  }
}

/// Default [ExternalUrlOpener]: hands the URL to the host OS's browser-opener
/// (`open` on macOS, `xdg-open` on Linux, `start` on Windows). The view injects
/// this only in production; tests supply their own opener.
Future<bool> _launchInExternalBrowser(Uri url) async {
  final target = url.toString();
  final (executable, arguments) = switch (Platform.operatingSystem) {
    'macos' => ('open', [target]),
    'windows' => ('cmd', ['/c', 'start', '', target]),
    _ => ('xdg-open', [target]),
  };
  try {
    final result = await Process.run(executable, arguments);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

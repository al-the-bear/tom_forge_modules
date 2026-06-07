// WebsitePreviewController — resolves the active website's preview URL and owns
// the refresh / source-toggle / external-open state for the preview view (§4,
// §9.3).
//
// The controller wraps the shared [WebsiteEditorController]; URL resolution is
// delegated to the proven PlaceholderResolver. These tests cover the preview
// layer's own behaviour: which template is resolved for each source, recompute
// on website change, refresh-token bumping, resolution-failure surfacing, and
// external-browser open through an injected opener.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _config = '''
version: 1
defaults:
  placeholders:
    port: "8080"
websites:
  - id: alpha
    label: Alpha
    paths:
      websiteRoot: "/sites/a"
      builtDir: "/sites/a/build"
    preview:
      devUrl: "http://localhost:{port}"
      builtIndex: "file://{builtDir}/index.html"
  - id: beta
    paths:
      websiteRoot: "/sites/b"
    preview:
      devUrl: "http://localhost:9000"
  - id: broken
    paths:
      websiteRoot: "/sites/c"
    preview:
      devUrl: "http://localhost:{missing}"
''';

/// A config reader returning a fixed [source].
class _StubReader {
  _StubReader(this.source);
  String source;
  Future<String> read() async => source;
}

/// Records the urls passed to it; always reports success.
class _StubOpener {
  final List<Uri> opened = [];

  Future<bool> call(Uri url) async {
    opened.add(url);
    return true;
  }
}

Future<WebsiteEditorController> _loadedEditor() async {
  final editor = WebsiteEditorController(configReader: _StubReader(_config).read);
  await editor.load();
  return editor;
}

void main() {
  group('WebsitePreviewController source resolution', () {
    test('TWE-PREV-CTL-01: devUrl resolves placeholders for active website',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      expect(controller.source, WebsitePreviewSource.devUrl);
      expect(controller.previewUrl, 'http://localhost:8080');
      expect(controller.resolveError, isNull);
    });

    test('TWE-PREV-CTL-02: setSource(builtIndex) resolves the built index URL',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.setSource(WebsitePreviewSource.builtIndex);
      expect(controller.source, WebsitePreviewSource.builtIndex);
      expect(controller.previewUrl, 'file:///sites/a/build/index.html');
      expect(notified, isTrue);
    });

    test('TWE-PREV-CTL-03: selecting a website recomputes the preview URL',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.selectWebsite('beta');
      expect(controller.activeWebsiteId, 'beta');
      expect(controller.previewUrl, 'http://localhost:9000');
      expect(notified, isTrue);
    });

    test('TWE-PREV-CTL-04: missing source key yields null URL, no error',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      controller.selectWebsite('beta'); // beta has no builtIndex
      controller.setSource(WebsitePreviewSource.builtIndex);
      expect(controller.previewUrl, isNull);
      expect(controller.resolveError, isNull);
    });

    test('TWE-PREV-CTL-05: unknown placeholder surfaces resolveError, null URL',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      controller.selectWebsite('broken');
      expect(controller.previewUrl, isNull);
      expect(controller.resolveError, isNotNull);
      expect(controller.resolveError!.token, 'missing');
    });

    test('TWE-PREV-CTL-06: unloaded editor yields null URL and no error', () {
      final editor =
          WebsiteEditorController(configReader: _StubReader(_config).read);
      final controller = WebsitePreviewController(editor: editor);
      expect(controller.previewUrl, isNull);
      expect(controller.resolveError, isNull);
      expect(controller.websites, isEmpty);
    });
  });

  group('WebsitePreviewController.refresh', () {
    test('TWE-PREV-CTL-07: refresh bumps the reload token and notifies',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      final before = controller.reloadToken;
      var notified = false;
      controller.addListener(() => notified = true);
      controller.refresh();
      expect(controller.reloadToken, greaterThan(before));
      expect(notified, isTrue);
    });
  });

  group('WebsitePreviewController.openInExternalBrowser', () {
    test('TWE-PREV-CTL-08: opens resolved URL via the injected opener',
        () async {
      final editor = await _loadedEditor();
      final opener = _StubOpener();
      final controller =
          WebsitePreviewController(editor: editor, externalOpener: opener.call);
      final ok = await controller.openInExternalBrowser();
      expect(ok, isTrue);
      expect(opener.opened, [Uri.parse('http://localhost:8080')]);
    });

    test('TWE-PREV-CTL-09: no URL → opener not called, returns false', () async {
      final editor = await _loadedEditor();
      final opener = _StubOpener();
      final controller =
          WebsitePreviewController(editor: editor, externalOpener: opener.call);
      controller.selectWebsite('broken'); // resolves to null
      final ok = await controller.openInExternalBrowser();
      expect(ok, isFalse);
      expect(opener.opened, isEmpty);
    });
  });

  group('WebsitePreviewController lifecycle', () {
    test('TWE-PREV-CTL-10: dispose stops reacting to editor changes', () async {
      final editor = await _loadedEditor();
      final controller = WebsitePreviewController(editor: editor);
      controller.dispose();
      // Mutating the editor after dispose must not throw (listener removed).
      editor.selectWebsite('beta');
      expect(editor.activeWebsiteId, 'beta');
    });
  });
}

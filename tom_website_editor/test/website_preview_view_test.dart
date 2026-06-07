// WebsitePreviewView — the preview panel embedding the active website (§4,
// §9.3).
//
// The real webview (InAppWebView) needs a platform; these tests inject a stub
// webview builder that renders the URL + reload token as text, so the view's
// own wiring is exercised headlessly: URL rendering, source toggle, website
// picker, refresh, error surfacing, external-open, and the reactive title.
import 'package:flutter/material.dart';
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

class _StubReader {
  _StubReader(this.source);
  String source;
  Future<String> read() async => source;
}

class _StubOpener {
  final List<Uri> opened = [];
  Future<bool> call(Uri url) async {
    opened.add(url);
    return true;
  }
}

/// Stub webview builder rendering the URL and reload token as inspectable text.
Widget _stubWebView(BuildContext context, String url, int reloadToken) =>
    Text('WEBVIEW:$url#$reloadToken');

Future<WebsitePreviewController> _loadedController({_StubOpener? opener}) async {
  final editor =
      WebsiteEditorController(configReader: _StubReader(_config).read);
  await editor.load();
  return WebsitePreviewController(
    editor: editor,
    externalOpener: opener?.call,
  );
}

Future<void> _pump(WidgetTester tester, WebsitePreviewView view) =>
    tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Builder(builder: view.buildMain))),
    );

void main() {
  testWidgets('TWE-PREV-VIEW-01: renders the resolved dev URL in the webview',
      (tester) async {
    final controller = await _loadedController();
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    expect(find.text('WEBVIEW:http://localhost:8080#0'), findsOneWidget);
  });

  testWidgets('TWE-PREV-VIEW-02: source toggle switches to the built index URL',
      (tester) async {
    final controller = await _loadedController();
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    await tester.tap(find.text('Built'));
    await tester.pumpAndSettle();
    expect(
      find.text('WEBVIEW:file:///sites/a/build/index.html#0'),
      findsOneWidget,
    );
  });

  testWidgets('TWE-PREV-VIEW-03: website picker changes the previewed site',
      (tester) async {
    final controller = await _loadedController();
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('beta').last);
    await tester.pumpAndSettle();
    expect(find.text('WEBVIEW:http://localhost:9000#0'), findsOneWidget);
  });

  testWidgets('TWE-PREV-VIEW-04: refresh bumps the reload token', (tester) async {
    final controller = await _loadedController();
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    await tester.tap(find.byTooltip('Reload preview'));
    await tester.pumpAndSettle();
    expect(find.text('WEBVIEW:http://localhost:8080#1'), findsOneWidget);
  });

  testWidgets('TWE-PREV-VIEW-05: resolution failure shows an error, not webview',
      (tester) async {
    final controller = await _loadedController();
    controller.selectWebsite('broken');
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    expect(find.textContaining('missing'), findsOneWidget);
    expect(find.textContaining('WEBVIEW:'), findsNothing);
  });

  testWidgets('TWE-PREV-VIEW-06: open-external action calls the opener',
      (tester) async {
    final opener = _StubOpener();
    final controller = await _loadedController(opener: opener);
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    await tester.tap(find.byTooltip('Open in external browser'));
    await tester.pumpAndSettle();
    expect(opener.opened, [Uri.parse('http://localhost:8080')]);
  });

  testWidgets('TWE-PREV-VIEW-07: title reflects the active website', (tester) async {
    final controller = await _loadedController();
    final view = WebsitePreviewView(
      controller: controller,
      webViewBuilder: _stubWebView,
    );
    await _pump(tester, view);
    expect(view.title.value, contains('alpha'));
    controller.selectWebsite('beta');
    await tester.pumpAndSettle();
    expect(view.title.value, contains('beta'));
  });
}

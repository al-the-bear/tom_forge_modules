// WebsiteConfigPanel — the settings-dialog UI for website selection + reload.
//
// Drives the panel through a real WebsiteEditorController backed by a stub
// reader so the tests exercise the wiring end to end: website tiles render,
// the active website is selected, tapping a tile changes the active selection,
// the reload button re-reads the source, and config issues are listed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _twoSites = '''
version: 1
websites:
  - id: alpha
    label: Alpha Site
    paths: { websiteRoot: "/a" }
  - id: beta
    paths: { websiteRoot: "/b" }
''';

const _invalid = 'version: 1\nwebsites: []\n';

class _StubReader {
  _StubReader(this.source);
  String source;
  Future<String> read() async => source;
}

Future<void> _pumpPanel(
  WidgetTester tester,
  WebsiteEditorController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WebsiteConfigPanel(controller: controller),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TWE-PANEL-01: renders a tile per website, active selected',
      (tester) async {
    final controller =
        WebsiteEditorController(configReader: _StubReader(_twoSites).read);
    await controller.load();
    await _pumpPanel(tester, controller);

    expect(find.text('Alpha Site'), findsOneWidget); // label preferred
    expect(find.text('beta'), findsOneWidget); // falls back to id
    final tiles = tester.widgetList<RadioListTile<String>>(
        find.byType(RadioListTile<String>));
    expect(tiles.length, 2);
    expect(controller.activeWebsiteId, 'alpha'); // active by default
  });

  testWidgets('TWE-PANEL-02: tapping a website tile selects it', (tester) async {
    final controller =
        WebsiteEditorController(configReader: _StubReader(_twoSites).read);
    await controller.load();
    await _pumpPanel(tester, controller);

    await tester.tap(find.text('beta'));
    await tester.pump();

    expect(controller.activeWebsiteId, 'beta');
  });

  testWidgets('TWE-PANEL-03: reload button re-reads and applies new source',
      (tester) async {
    final reader = _StubReader(_twoSites);
    final controller = WebsiteEditorController(configReader: reader.read);
    await controller.load();
    await _pumpPanel(tester, controller);

    reader.source = '''
version: 1
websites:
  - id: gamma
    paths: { websiteRoot: "/g" }
''';
    await tester.tap(find.text('Reload configuration'));
    await tester.pumpAndSettle();

    expect(controller.activeWebsiteId, 'gamma');
    expect(find.text('gamma'), findsOneWidget);
  });

  testWidgets('TWE-PANEL-04: lists issues when the config is invalid',
      (tester) async {
    final controller =
        WebsiteEditorController(configReader: _StubReader(_invalid).read);
    await controller.load();
    await _pumpPanel(tester, controller);

    expect(find.text('Issues'), findsOneWidget);
    expect(find.text('No valid configuration loaded.'), findsOneWidget);
  });
}

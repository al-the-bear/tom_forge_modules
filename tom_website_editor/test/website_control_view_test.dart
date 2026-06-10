// WebsiteControlView — the control panel (§5): one button per configured
// command, a levelled/filterable message log, and a status line. The view holds
// no state; it renders the [WebsiteControlController] and drives it on tap.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _config = '''
version: 1
defaults:
  shell: ["bash", "-lc"]
websites:
  - id: alpha
    label: Alpha
    paths:
      websiteRoot: "/sites/a"
    cwd: "{websiteRoot}"
    commands:
      generateAll: "dart run tool/gen_all.dart"
      build: "jaspr build"
      serveStart: "jaspr serve"
  - id: beta
    label: Beta
    paths:
      websiteRoot: "/sites/b"
    commands:
      build: "jaspr build"
''';

class _StubReader {
  _StubReader(this.source);
  String source;
  Future<String> read() async => source;
}

class _FakeHandle implements WebsiteProcessHandle {
  _FakeHandle(this._code);
  final int _code;
  @override
  Stream<WebsiteProcessLine> get output => const Stream.empty();
  @override
  Future<int> get exitCode => Future.value(_code);
  @override
  Future<void> kill() async {}
}

class _FakeRunner implements WebsiteProcessRunner {
  _FakeRunner({this.code = 0});
  int code;
  final List<WebsiteCommandSpec> specs = [];
  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) {
    specs.add(spec);
    return _FakeHandle(code);
  }
}

/// A long-lived handle whose exit is gated by the test — needed for the
/// dev-server toggle, where the process must stay "running" after the tap.
class _GatedHandle implements WebsiteProcessHandle {
  final _exit = Completer<int>();
  @override
  Stream<WebsiteProcessLine> get output => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  Future<void> kill() async {
    if (!_exit.isCompleted) _exit.complete(0);
  }
}

class _GatedRunner implements WebsiteProcessRunner {
  final List<WebsiteCommandSpec> specs = [];
  final List<_GatedHandle> handles = [];
  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) {
    specs.add(spec);
    final handle = _GatedHandle();
    handles.add(handle);
    return handle;
  }
}

Future<WebsiteControlController> _loadedController(
    WebsiteProcessRunner runner) async {
  final editor = WebsiteEditorController(configReader: _StubReader(_config).read);
  await editor.load();
  return WebsiteControlController(editor: editor, runner: runner);
}

Future<void> _pump(WidgetTester tester, WebsiteControlView view) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: view.buildMain)),
  ));
}

void main() {
  testWidgets('TWE-CTRLV-01: configured commands render enabled, missing disabled',
      (tester) async {
    final controller = await _loadedController(_FakeRunner());
    await _pump(tester, WebsiteControlView(controller: controller));

    final build = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Build'),
    );
    expect(build.onPressed, isNotNull);

    final extract = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Extract design'),
    );
    expect(extract.onPressed, isNull);
  });

  testWidgets('TWE-CTRLV-02: tapping a command spawns the process', (tester) async {
    final runner = _FakeRunner();
    final controller = await _loadedController(runner);
    await _pump(tester, WebsiteControlView(controller: controller));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Build'));
    await tester.pumpAndSettle();

    expect(runner.specs.single.display, 'jaspr build');
  });

  testWidgets('TWE-CTRLV-03: log shows the command echo and completion',
      (tester) async {
    final runner = _FakeRunner(code: 0);
    final controller = await _loadedController(runner);
    await _pump(tester, WebsiteControlView(controller: controller));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Build'));
    await tester.pumpAndSettle();

    expect(find.textContaining('jaspr build'), findsWidgets);
    expect(find.textContaining('completed'), findsOneWidget);
  });

  testWidgets('TWE-CTRLV-04: website picker switches the active website',
      (tester) async {
    final controller = await _loadedController(_FakeRunner());
    await _pump(tester, WebsiteControlView(controller: controller));

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();

    expect(controller.activeWebsiteId, 'beta');
    expect(
      tester
          .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Generate all'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('TWE-CTRLV-05: status line shows active website + counts',
      (tester) async {
    final runner = _FakeRunner(code: 1);
    final controller = await _loadedController(runner);
    await _pump(tester, WebsiteControlView(controller: controller));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Build'));
    await tester.pumpAndSettle();

    expect(find.textContaining('alpha'), findsWidgets);
    expect(find.textContaining('1 error'), findsOneWidget);
  });

  testWidgets('TWE-CTRLV-06: title reflects the active website', (tester) async {
    final controller = await _loadedController(_FakeRunner());
    final view = WebsiteControlView(controller: controller);
    await _pump(tester, view);
    expect(view.title.value, 'Control: alpha');
  });

  testWidgets('TWE-CTRLV-07: error filter hides info, keeps errors',
      (tester) async {
    final runner = _FakeRunner(code: 1);
    final controller = await _loadedController(runner);
    await _pump(tester, WebsiteControlView(controller: controller));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Build'));
    await tester.pumpAndSettle();

    // Turn off info + warning filters, leaving only errors.
    await tester.tap(find.widgetWithText(FilterChip, 'Info'));
    await tester.pumpAndSettle();

    expect(find.textContaining('failed (exit 1)'), findsOneWidget);
    expect(find.textContaining('completed'), findsNothing);
  });

  testWidgets('TWE-CTRLV-09: log is wrapped in a SelectionArea (multi-line '
      'selectable), not per-line SelectableText', (tester) async {
    final controller = await _loadedController(_FakeRunner());
    await _pump(tester, WebsiteControlView(controller: controller));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Build'));
    await tester.pumpAndSettle();

    // The log content is wrapped in one SelectionArea so a drag spans lines.
    expect(find.byType(SelectionArea), findsOneWidget);
    // The old per-line SelectableText (which trapped selection to one line) is
    // gone from the log.
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('TWE-CTRLV-10: Copy log puts all visible lines on the clipboard',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final controller = await _loadedController(_FakeRunner(code: 0));
    await _pump(tester, WebsiteControlView(controller: controller));

    final copyButton =
        find.widgetWithIcon(IconButton, Icons.copy_all_outlined);
    // Empty log → Copy log disabled.
    expect(tester.widget<IconButton>(copyButton).onPressed, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Build'));
    await tester.pumpAndSettle();

    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(copied, isNotEmpty);
    // Multiple log lines joined by newlines (the echo line + completion line).
    expect(copied.last, contains('jaspr build'));
    expect(copied.last, contains('completed'));
    expect(copied.last, contains('\n'));
  });

  testWidgets('TWE-CTRLV-08: dev-server button toggles start → stop + status',
      (tester) async {
    final runner = _GatedRunner();
    final controller = await _loadedController(runner);
    await _pump(tester, WebsiteControlView(controller: controller));

    // Before starting: the toggle reads "Start dev server" and status is stopped.
    expect(find.widgetWithText(ElevatedButton, 'Start dev server'),
        findsOneWidget);
    expect(find.textContaining('server: stopped'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start dev server'));
    await tester.pumpAndSettle();

    // The server stays running (gated handle): the toggle flips and the status
    // line + restart control reflect the running server.
    expect(controller.isServerRunning, isTrue);
    expect(runner.specs.single.display, 'jaspr serve');
    expect(find.widgetWithText(ElevatedButton, 'Stop dev server'),
        findsOneWidget);
    expect(find.textContaining('server: running'), findsOneWidget);
    expect(find.byTooltip('Restart dev server'), findsOneWidget);

    // Stop it again so the controller's supervisor future settles cleanly.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Stop dev server'));
    await tester.pumpAndSettle();
    expect(controller.isServerRunning, isFalse);
  });
}

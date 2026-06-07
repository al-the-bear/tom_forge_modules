// WebsiteControlController dev-server lifecycle (§5, §9.5).
//
// serveStart is a long-lived child process the controller owns: it is started
// without blocking, tracked, stoppable, and restartable, and its stdout is
// watched for a rebuild-complete marker that triggers an injected refresh
// callback (wired to the preview view in production). These tests drive a gated
// fake process so the server stays "running" until the test ends it.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _config = '''
version: 1
defaults:
  shell: ["bash", "-lc"]
  placeholders:
    port: "8080"
websites:
  - id: alpha
    label: Alpha
    paths:
      websiteRoot: "/sites/a"
    cwd: "{websiteRoot}"
    commands:
      build: "jaspr build"
      serveStart: "jaspr serve --port {port}"
  - id: beta
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

/// A long-lived handle whose output + exit are driven by the test.
class _GatedHandle implements WebsiteProcessHandle {
  final _exit = Completer<int>();
  final _output = StreamController<WebsiteProcessLine>();
  bool killed = false;

  void emit(ProcessStream stream, String text) =>
      _output.add(WebsiteProcessLine(stream, text));

  void finish(int code) {
    if (!_output.isClosed) _output.close();
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  Stream<WebsiteProcessLine> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> kill() async {
    killed = true;
    finish(0);
  }
}

class _GatedRunner implements WebsiteProcessRunner {
  final List<_GatedHandle> handles = [];
  final List<WebsiteCommandSpec> specs = [];

  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) {
    specs.add(spec);
    final handle = _GatedHandle();
    handles.add(handle);
    return handle;
  }
}

Future<WebsiteEditorController> _loadedEditor() async {
  final editor = WebsiteEditorController(configReader: _StubReader(_config).read);
  await editor.load();
  return editor;
}

void main() {
  group('startServer / stopServer', () {
    test('TWE-SRV-01: startServer spawns serveStart without blocking',
        () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final ok = await controller.startServer();
      expect(ok, isTrue);
      expect(controller.isServerRunning, isTrue);
      expect(controller.serverWebsiteId, 'alpha');
      expect(runner.specs.single.display, 'jaspr serve --port 8080');
      await controller.stopServer();
    });

    test('TWE-SRV-02: startServer with no serveStart → error, false', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      controller.selectWebsite('beta'); // beta has no serveStart
      final ok = await controller.startServer();
      expect(ok, isFalse);
      expect(controller.isServerRunning, isFalse);
      expect(runner.specs, isEmpty);
      expect(controller.log.last.level, WebsiteLogLevel.error);
    });

    test('TWE-SRV-03: stopServer kills the child and clears state', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.startServer();
      await controller.stopServer();
      expect(runner.handles.single.killed, isTrue);
      expect(controller.isServerRunning, isFalse);
      expect(controller.serverWebsiteId, isNull);
    });

    test('TWE-SRV-04: startServer while running is a no-op (single spawn)',
        () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.startServer();
      final second = await controller.startServer();
      expect(second, isFalse);
      expect(runner.handles, hasLength(1));
      await controller.stopServer();
    });

    test('TWE-SRV-05: restartServer stops then starts a fresh child', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.startServer();
      final ok = await controller.restartServer();
      expect(ok, isTrue);
      expect(controller.isServerRunning, isTrue);
      expect(runner.handles, hasLength(2));
      expect(runner.handles.first.killed, isTrue);
      await controller.stopServer();
    });

    test('TWE-SRV-09: server exiting on its own clears state + logs', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.startServer();
      runner.handles.single.finish(1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isServerRunning, isFalse);
      expect(
        controller.log.any((e) =>
            e.message.toLowerCase().contains('dev server') &&
            e.message.contains('1')),
        isTrue,
      );
    });
  });

  group('auto-refresh on rebuild', () {
    test('TWE-SRV-06: a matching stdout line fires onRebuildComplete',
        () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      var refreshes = 0;
      final controller = WebsiteControlController(
        editor: editor,
        runner: runner,
        onRebuildComplete: () => refreshes++,
        rebuildMatcher: (line) => line.contains('RELOAD'),
      );
      await controller.startServer();
      runner.handles.single.emit(ProcessStream.stdout, 'RELOAD done');
      await Future<void>.delayed(Duration.zero);
      expect(refreshes, 1);
      await controller.stopServer();
    });

    test('TWE-SRV-07: a non-matching line does not fire refresh', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      var refreshes = 0;
      final controller = WebsiteControlController(
        editor: editor,
        runner: runner,
        onRebuildComplete: () => refreshes++,
        rebuildMatcher: (line) => line.contains('RELOAD'),
      );
      await controller.startServer();
      runner.handles.single.emit(ProcessStream.stdout, 'compiling main.dart');
      await Future<void>.delayed(Duration.zero);
      expect(refreshes, 0);
      await controller.stopServer();
    });

    test('TWE-SRV-08: server output streams into the log by level', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.startServer();
      runner.handles.single.emit(ProcessStream.stdout, 'serving at 8080');
      runner.handles.single.emit(ProcessStream.stderr, 'minor warning');
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.log.any((e) =>
            e.level == WebsiteLogLevel.info && e.message == 'serving at 8080'),
        isTrue,
      );
      expect(
        controller.log.any((e) =>
            e.level == WebsiteLogLevel.warning && e.message == 'minor warning'),
        isTrue,
      );
      await controller.stopServer();
    });

    test('TWE-SRV-11: the default matcher recognizes reload-style lines', () {
      expect(WebsiteControlController.isRebuildCompleteLine('Reloading browser'),
          isTrue);
      expect(WebsiteControlController.isRebuildCompleteLine('Recompiled in 1s'),
          isTrue);
      expect(
          WebsiteControlController.isRebuildCompleteLine('compiling main.dart'),
          isFalse);
    });
  });
}

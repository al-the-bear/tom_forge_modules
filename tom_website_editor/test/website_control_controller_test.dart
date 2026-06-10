// WebsiteControlController — renders one button per configured command, spawns
// the external process for the active website, streams stdout/stderr into a
// levelled log, and maps the exit code via the §7 taxonomy (§5, §9.4).
//
// The controller wraps the shared [WebsiteEditorController]; process spawning is
// delegated to an injected [WebsiteProcessRunner] so these tests never start a
// real process. They cover button availability, command/cwd expansion, the
// log-before-run echo, stdout/stderr log levels, the 0/1/2 exit-code mapping,
// the --dry-run flag, unconfigured-command and resolve-error handling, and the
// running/stop lifecycle.
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
      generateContent: "dart run tool/gen_content.dart"
      generateAll: "dart run tool/gen_all.dart"
      build: "jaspr build"
      deploy: "./deploy.sh"
      broken: "echo {missing}"
  - id: beta
    paths:
      websiteRoot: "/sites/b"
    commands:
      build: "jaspr build"
''';

/// Like [_config]'s alpha but with `serveStart` configured, so tests can start
/// the long-lived dev server and exercise the build-lock guard.
const _configWithServe = '''
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
''';

class _StubReader {
  _StubReader(this.source);
  String source;
  Future<String> read() async => source;
}

/// A handle that replays [lines] then completes with [code].
class _FakeHandle implements WebsiteProcessHandle {
  _FakeHandle(this._lines, this._code);
  final List<WebsiteProcessLine> _lines;
  final int _code;
  bool killed = false;

  @override
  Stream<WebsiteProcessLine> get output => Stream.fromIterable(_lines);

  @override
  Future<int> get exitCode => Future.value(_code);

  @override
  Future<void> kill() async => killed = true;
}

/// Records every spec it is asked to start and returns a [_FakeHandle].
class _FakeRunner implements WebsiteProcessRunner {
  _FakeRunner({this.lines = const [], this.code = 0});
  List<WebsiteProcessLine> lines;
  int code;
  final List<WebsiteCommandSpec> specs = [];

  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) {
    specs.add(spec);
    return _FakeHandle(lines, code);
  }
}

/// A handle whose completion is controlled by the test, for in-flight state.
class _GatedHandle implements WebsiteProcessHandle {
  final _exit = Completer<int>();
  final _output = StreamController<WebsiteProcessLine>();
  bool killed = false;

  void finish(int code) {
    _output.close();
    _exit.complete(code);
  }

  @override
  Stream<WebsiteProcessLine> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> kill() async => killed = true;
}

class _GatedRunner implements WebsiteProcessRunner {
  final List<_GatedHandle> handles = [];

  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) {
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

WebsiteCommandButton _button(WebsiteControlController c, String name) =>
    c.buttons.firstWhere((b) => b.name == name);

void main() {
  group('WebsiteControlController buttons', () {
    test('TWE-CTRL-01: canonical commands appear, configured enabled', () async {
      final editor = await _loadedEditor();
      final controller = WebsiteControlController(editor: editor);
      expect(_button(controller, 'generateAll').isAvailable, isTrue);
      expect(_button(controller, 'build').isAvailable, isTrue);
      expect(_button(controller, 'extractDesign').isAvailable, isFalse);
      expect(_button(controller, 'serveStart').isAvailable, isFalse);
    });

    test('TWE-CTRL-02: extra configured command appears after canonical ones',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsiteControlController(editor: editor);
      final deploy = _button(controller, 'deploy');
      expect(deploy.isAvailable, isTrue);
      final names = controller.buttons.map((b) => b.name).toList();
      expect(names.indexOf('deploy'), greaterThan(names.indexOf('openBrowser')));
    });

    test('TWE-CTRL-12: selecting a website recomputes buttons + notifies',
        () async {
      final editor = await _loadedEditor();
      final controller = WebsiteControlController(editor: editor);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.selectWebsite('beta');
      expect(controller.activeWebsiteId, 'beta');
      expect(_button(controller, 'generateAll').isAvailable, isFalse);
      expect(_button(controller, 'build').isAvailable, isTrue);
      expect(notified, isTrue);
    });
  });

  group('WebsiteControlController.runCommand dispatch', () {
    test('TWE-CTRL-03: builds shell argv + expanded cwd from the template',
        () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.runCommand('generateAll');
      final spec = runner.specs.single;
      expect(spec.executable, 'bash');
      expect(spec.arguments, ['-lc', 'dart run tool/gen_all.dart']);
      expect(spec.workingDirectory, '/sites/a');
      expect(spec.display, 'dart run tool/gen_all.dart');
    });

    test('TWE-CTRL-04: logs the expanded command + cwd before running',
        () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.runCommand('generateAll');
      final echo = controller.log.first;
      expect(echo.level, WebsiteLogLevel.info);
      expect(echo.message, contains('dart run tool/gen_all.dart'));
      expect(echo.message, contains('/sites/a'));
    });

    test('TWE-CTRL-05: stdout → info, stderr → warning', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner(lines: const [
        WebsiteProcessLine(ProcessStream.stdout, 'building'),
        WebsiteProcessLine(ProcessStream.stderr, 'deprecated api'),
      ]);
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.runCommand('build');
      expect(
        controller.log.any((e) =>
            e.level == WebsiteLogLevel.info && e.message == 'building'),
        isTrue,
      );
      expect(
        controller.log.any((e) =>
            e.level == WebsiteLogLevel.warning && e.message == 'deprecated api'),
        isTrue,
      );
    });

    test('TWE-CTRL-06: exit 0 → info completion, no error', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner(code: 0);
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final code = await controller.runCommand('build');
      expect(code, 0);
      expect(controller.errorCount, 0);
      expect(controller.log.last.level, WebsiteLogLevel.info);
      expect(controller.lastRunAt, isNotNull);
    });

    test('TWE-CTRL-07: exit 1 → pinned error mentioning exit 1', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner(code: 1);
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final code = await controller.runCommand('build');
      expect(code, 1);
      final err = controller.log.lastWhere((e) => e.level == WebsiteLogLevel.error);
      expect(err.pinned, isTrue);
      expect(err.message, contains('1'));
      expect(controller.errorCount, greaterThanOrEqualTo(1));
    });

    test('TWE-CTRL-08: exit 2 → pinned error tagged usage/config', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner(code: 2);
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final code = await controller.runCommand('build');
      expect(code, 2);
      final err = controller.log.lastWhere((e) => e.level == WebsiteLogLevel.error);
      expect(err.pinned, isTrue);
      expect(err.message.toLowerCase(), contains('usage'));
    });

    test('TWE-CTRL-09: dryRun appends --dry-run to the command', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      await controller.runCommand('generateAll', dryRun: true);
      final spec = runner.specs.single;
      expect(spec.arguments.last, 'dart run tool/gen_all.dart --dry-run');
      expect(spec.display, 'dart run tool/gen_all.dart --dry-run');
    });

    test('TWE-CTRL-10: unconfigured command → error, no dispatch', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final code = await controller.runCommand('serveStart');
      expect(code, isNull);
      expect(runner.specs, isEmpty);
      expect(controller.log.last.level, WebsiteLogLevel.error);
    });

    test('TWE-CTRL-11: placeholder error → pinned error, no dispatch',
        () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final code = await controller.runCommand('broken');
      expect(code, isNull);
      expect(runner.specs, isEmpty);
      final err =
          controller.log.lastWhere((e) => e.level == WebsiteLogLevel.error);
      expect(err.pinned, isTrue);
      expect(err.message, contains('missing'));
    });
  });

  group('WebsiteControlController lifecycle', () {
    test('TWE-CTRL-13: isRunning true while in flight, false after', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final future = controller.runCommand('build');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isRunning('build'), isTrue);
      expect(_button(controller, 'build').isRunning, isTrue);
      runner.handles.single.finish(0);
      await future;
      expect(controller.isRunning('build'), isFalse);
      expect(_button(controller, 'build').isRunning, isFalse);
    });

    test('TWE-CTRL-14: stop kills the running handle', () async {
      final editor = await _loadedEditor();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);
      final future = controller.runCommand('build');
      await Future<void>.delayed(Duration.zero);
      await controller.stop('build');
      expect(runner.handles.single.killed, isTrue);
      runner.handles.single.finish(0);
      await future;
    });

    test('TWE-CTRL-19: build is refused (pinned error, no dispatch) while the '
        'dev server is running', () async {
      final editor = WebsiteEditorController(
          configReader: _StubReader(_configWithServe).read);
      await editor.load();
      final runner = _GatedRunner();
      final controller =
          WebsiteControlController(editor: editor, runner: runner);

      // Start the long-lived dev server (handle stays open).
      expect(await controller.startServer(), isTrue);
      expect(controller.isServerRunning, isTrue);
      final serverHandle = runner.handles.single;

      final code = await controller.runCommand('build');
      expect(code, isNull, reason: 'build must not run while server is up');
      // Only the server was started — build was never dispatched.
      expect(runner.handles.length, 1);
      final err =
          controller.log.lastWhere((e) => e.level == WebsiteLogLevel.error);
      expect(err.pinned, isTrue);
      expect(err.message, contains('dev server'));
      expect(err.message.toLowerCase(), contains('build_runner'));

      // Once the server stops, build runs normally.
      serverHandle.finish(0);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.isServerRunning, isFalse);
      final buildFuture = controller.runCommand('build');
      await Future<void>.delayed(Duration.zero);
      runner.handles[1].finish(0);
      expect(await buildFuture, 0);
      expect(runner.handles.length, 2);
    });

    test('TWE-CTRL-15: dispose stops reacting to editor changes', () async {
      final editor = await _loadedEditor();
      final controller = WebsiteControlController(editor: editor);
      controller.dispose();
      editor.selectWebsite('beta');
      expect(editor.activeWebsiteId, 'beta');
    });
  });

  group('WebsiteControlController content-regeneration refresh', () {
    test('TWE-CTRL-16: generateAll fires onContentRegenerated once + logs drift',
        () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner(lines: const [
        WebsiteProcessLine(ProcessStream.stdout, 'drift: 2 added, 0 removed'),
      ]);
      var regen = 0;
      final controller = WebsiteControlController(
        editor: editor,
        runner: runner,
        onContentRegenerated: () => regen++,
      );
      await controller.runCommand('generateAll');
      expect(regen, 1);
      expect(
        controller.log.any((e) => e.message.contains('drift: 2 added')),
        isTrue,
      );
    });

    test('TWE-CTRL-17: generateContent fires it; build does not', () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      var regen = 0;
      final controller = WebsiteControlController(
        editor: editor,
        runner: runner,
        onContentRegenerated: () => regen++,
      );
      await controller.runCommand('generateContent');
      expect(regen, 1);
      await controller.runCommand('build');
      expect(regen, 1);
    });

    test('TWE-CTRL-18: dry-run generate does not fire onContentRegenerated',
        () async {
      final editor = await _loadedEditor();
      final runner = _FakeRunner();
      var regen = 0;
      final controller = WebsiteControlController(
        editor: editor,
        runner: runner,
        onContentRegenerated: () => regen++,
      );
      await controller.runCommand('generateAll', dryRun: true);
      expect(regen, 0);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A fully-resolved command ready to spawn (§5, §7).
///
/// The placeholders in a website's command template have already been expanded
/// by the time a spec exists: [executable] + [arguments] is the argv (built from
/// `defaults.shell` plus the expanded command line), [workingDirectory] is the
/// expanded `cwd`, and [display] is the human-readable line shown in the log
/// before the run.
class WebsiteCommandSpec {
  const WebsiteCommandSpec({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.display,
  });

  /// The program to run (typically the shell, e.g. `bash`).
  final String executable;

  /// Arguments passed to [executable] (e.g. `['-lc', 'jaspr build']`).
  final List<String> arguments;

  /// Expanded working directory for the process (§7: the website `cwd`).
  final String workingDirectory;

  /// The expanded command line as shown to the user in the log.
  final String display;
}

/// Which standard stream a [WebsiteProcessLine] came from.
enum ProcessStream { stdout, stderr }

/// A single line of process output, tagged with its origin stream.
class WebsiteProcessLine {
  const WebsiteProcessLine(this.stream, this.text);

  /// Whether the line came from stdout or stderr.
  final ProcessStream stream;

  /// The line text (without the trailing newline).
  final String text;
}

/// A running (or finished) external process spawned by a [WebsiteProcessRunner].
///
/// [output] streams stdout/stderr lines as they arrive; [exitCode] completes
/// with the process exit code (§7 taxonomy: `0` success, `1` failure, `2`
/// usage/config bug); [kill] terminates a long-lived child (e.g. `serveStart`).
abstract interface class WebsiteProcessHandle {
  /// Interleaved stdout/stderr lines, tagged by [ProcessStream].
  Stream<WebsiteProcessLine> get output;

  /// Completes with the process exit code once it terminates.
  Future<int> get exitCode;

  /// Requests termination of the process.
  Future<void> kill();
}

/// Spawns external processes for the control view (§5).
///
/// Injected so the controller can be exercised in tests without spawning real
/// processes — the module wires the [DartIoWebsiteProcessRunner] default; tests
/// supply a fake that replays predetermined output and an exit code.
abstract interface class WebsiteProcessRunner {
  /// Starts the process described by [spec].
  WebsiteProcessHandle start(WebsiteCommandSpec spec);
}

/// Default [WebsiteProcessRunner] backed by `dart:io` `Process.start`.
///
/// stdout/stderr are decoded as UTF-8 lines and interleaved into [output].
/// A failure to even spawn the process (`ProcessException` — e.g. the shell is
/// missing or the cwd does not exist) is reported as exit code `2`, matching the
/// §7 "usage/config bug" tag rather than masquerading as a real failure (`1`).
class DartIoWebsiteProcessRunner implements WebsiteProcessRunner {
  const DartIoWebsiteProcessRunner();

  @override
  WebsiteProcessHandle start(WebsiteCommandSpec spec) {
    final controller = StreamController<WebsiteProcessLine>();
    final exitCompleter = Completer<int>();
    Future<Process>? processFuture;

    Future<void> run() async {
      try {
        final process = await Process.start(
          spec.executable,
          spec.arguments,
          workingDirectory: spec.workingDirectory,
        );
        processFuture = Future.value(process);

        final stdoutDone = process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) =>
                controller.add(WebsiteProcessLine(ProcessStream.stdout, line)));
        final stderrDone = process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .forEach((line) =>
                controller.add(WebsiteProcessLine(ProcessStream.stderr, line)));

        await Future.wait([stdoutDone, stderrDone]);
        final code = await process.exitCode;
        if (!exitCompleter.isCompleted) exitCompleter.complete(code);
      } on ProcessException catch (e) {
        controller.add(WebsiteProcessLine(ProcessStream.stderr, e.message));
        if (!exitCompleter.isCompleted) exitCompleter.complete(2);
      } finally {
        await controller.close();
      }
    }

    unawaited(run());

    return _DartIoProcessHandle(
      output: controller.stream,
      exitCode: exitCompleter.future,
      processFuture: () => processFuture,
    );
  }
}

/// [WebsiteProcessHandle] over a `dart:io` [Process].
class _DartIoProcessHandle implements WebsiteProcessHandle {
  _DartIoProcessHandle({
    required Stream<WebsiteProcessLine> output,
    required Future<int> exitCode,
    required Future<Process>? Function() processFuture,
  })  : _output = output.asBroadcastStream(),
        _exitCode = exitCode,
        _processFuture = processFuture;

  final Stream<WebsiteProcessLine> _output;
  final Future<int> _exitCode;
  final Future<Process>? Function() _processFuture;

  @override
  Stream<WebsiteProcessLine> get output => _output;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  Future<void> kill() async {
    final process = await _processFuture();
    process?.kill();
  }
}

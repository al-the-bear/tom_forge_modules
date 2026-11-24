import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_office_editor/tom_office_editor.dart' show TomToolPlatform;

/// A process the install runner started, played by the test: [out] and
/// [err] write to its output, [exit] ends it; [kill] ends it with −15.
class FakeInstallProcess implements Process {
  /// The process [executable] [arguments] was started as, with
  /// [environment].
  FakeInstallProcess(this.executable, this.arguments, this.environment);

  /// What the runner started.
  final String executable;

  /// Its arguments.
  final List<String> arguments;

  /// The environment it was given.
  final Map<String, String>? environment;

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  /// Whether [kill] was called.
  bool killed = false;

  /// Whether it has ended.
  bool get exited => _exit.isCompleted;

  /// Writes [text] to its standard output.
  void out(String text) => _stdout.add(utf8.encode(text));

  /// Writes [text] to its standard error.
  void err(String text) => _stderr.add(utf8.encode(text));

  /// Ends it with [code].
  void exit(int code) {
    if (_exit.isCompleted) return;
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  Future<int> get exitCode => _exit.future;

  @override
  int get pid => 4242;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    exit(-15);
    return true;
  }

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

/// The install runner's process starter for tests
/// ([ForgeInstallProcessStarter]): every start is recorded in [started];
/// [onStart] plays the process (by default it stays running until the test
/// ends it). Nothing is ever really run.
class FakeInstallStarter {
  /// A starter; [onStart] plays each process as it starts.
  FakeInstallStarter({this.onStart});

  /// Plays a process as it starts (write output, create files, exit).
  void Function(FakeInstallProcess process)? onStart;

  /// The processes started, in order.
  final started = <FakeInstallProcess>[];

  /// The starter the runner takes.
  Future<Process> call(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final process = FakeInstallProcess(executable, arguments, environment);
    started.add(process);
    onStart?.call(process);
    return process;
  }
}

/// A managed download's HTTP for tests: [files] answers downloads, [texts]
/// the hash; every URL asked for is recorded in [requests].
class FakeInstallHttp extends ForgeInstallHttp {
  /// The fake.
  FakeInstallHttp({this.files = const {}, this.texts = const {}});

  /// What a download of a URL writes.
  final Map<String, List<int>> files;

  /// What a URL's text is.
  final Map<String, String> texts;

  /// The URLs asked for, in order.
  final requests = <String>[];

  @override
  Future<String> getText(Uri url) async {
    requests.add('$url');
    final text = texts['$url'];
    if (text == null) throw HttpException('HTTP 404', uri: url);
    return text;
  }

  @override
  Future<void> download(
    Uri url,
    File target, {
    required bool Function() cancelled,
    void Function(int received, int? total)? progress,
  }) async {
    requests.add('$url');
    final bytes = files['$url'];
    if (bytes == null) throw HttpException('HTTP 404', uri: url);
    if (cancelled()) throw const ForgeInstallCancelled();
    await target.writeAsBytes(bytes);
    progress?.call(bytes.length, bytes.length);
  }
}

/// An install runner for tests on [platform] (default macOS): processes
/// through [starter] (default: a [FakeInstallStarter] whose processes exit
/// 1), `PATH` `/usr/bin:/bin` and only [executables] on disk (default
/// Homebrew's `brew`), HTTP through [http]. It never runs a real install.
ForgeLibreOfficeInstaller forgeOfficeTestInstaller({
  FakeInstallStarter? starter,
  ForgeInstallHttp? http,
  TomToolPlatform platform = TomToolPlatform.macos,
  Set<String> executables = const {'/opt/homebrew/bin/brew'},
}) => ForgeLibreOfficeInstaller(
  startProcess: (starter ?? FakeInstallStarter(onStart: (p) => p.exit(1))).call,
  http: http ?? FakeInstallHttp(),
  environment: const {'PATH': '/usr/bin:/bin'},
  platform: platform,
  executableExists: executables.contains,
);

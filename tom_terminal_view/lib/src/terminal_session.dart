import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

/// What a [TomTerminalSession] starts: the shell and its arguments, where it
/// runs, its environment, the size of the pseudo-terminal and how many lines
/// the terminal keeps.
@immutable
class TomTerminalOptions {
  const TomTerminalOptions({
    this.shell,
    this.arguments = const [],
    this.workingDirectory,
    this.environment,
    this.columns = 80,
    this.rows = 25,
    this.scrollback = 10000,
    this.exitMessage = true,
  }) : assert(columns > 0),
       assert(rows > 0),
       assert(scrollback > 0);

  /// The path of the shell (or any program) to run; null: [defaultShell].
  final String? shell;

  /// The arguments the shell is started with.
  final List<String> arguments;

  /// The directory the shell starts in; null: the current directory.
  final String? workingDirectory;

  /// Variables set in the shell's environment, beside `TERM`, `LANG` and the
  /// user's `HOME`, `PATH`, `USER`, `LOGNAME` and `DISPLAY`.
  final Map<String, String>? environment;

  /// The width of the pseudo-terminal in characters until a view resizes it.
  final int columns;

  /// The height of the pseudo-terminal in lines until a view resizes it.
  final int rows;

  /// How many lines the terminal keeps, scrollback included.
  final int scrollback;

  /// Whether the session writes `[Process exited with code <n>]` into the
  /// terminal when the shell ends.
  final bool exitMessage;

  /// The shell that runs: [shell], else [defaultShell].
  String get effectiveShell => shell ?? defaultShell();

  /// The user's shell: `$SHELL` (`%COMSPEC%` on Windows), else `/bin/bash`
  /// (`cmd.exe`).
  static String defaultShell() {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    }
    return Platform.environment['SHELL'] ?? '/bin/bash';
  }
}

/// The process a [TomTerminalSession] talks to: by default a shell in a
/// pseudo-terminal ([TomPtyProcess]); a test may give its own.
abstract class TomTerminalProcess {
  /// What the process writes to the terminal.
  Stream<Uint8List> get output;

  /// Completes with the exit code when the process ends.
  Future<int> get exitCode;

  /// The process id.
  int get pid;

  /// Writes [data] to the process's input.
  void write(Uint8List data);

  /// Resizes the pseudo-terminal.
  void resize(int rows, int columns);

  /// Ends the process; false when it could not be signalled.
  bool kill();
}

/// Starts the process of a session for [options].
typedef TomTerminalProcessStarter =
    TomTerminalProcess Function(TomTerminalOptions options);

/// A shell in a pseudo-terminal (`flutter_pty`), on macOS, Linux and
/// Windows.
class TomPtyProcess implements TomTerminalProcess {
  TomPtyProcess._(this._pty);

  /// Starts [options]' shell in a pseudo-terminal.
  factory TomPtyProcess.start(TomTerminalOptions options) => TomPtyProcess._(
    Pty.start(
      options.effectiveShell,
      arguments: options.arguments,
      workingDirectory: options.workingDirectory,
      environment: options.environment,
      columns: options.columns,
      rows: options.rows,
    ),
  );

  final Pty _pty;

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  int get pid => _pty.pid;

  @override
  void write(Uint8List data) => _pty.write(data);

  @override
  void resize(int rows, int columns) => _pty.resize(rows, columns);

  @override
  bool kill() => _pty.kill();
}

/// A shell running in a terminal: the process ([TomTerminalProcess], a
/// pseudo-terminal unless another is given) and the xterm [terminal] model
/// a [TomTerminalView] shows.
///
/// What the shell writes goes into [terminal] and to [output]; what the user
/// types in the view, and what [write] / [sendText] send, goes to the shell;
/// a view's resize resizes the pseudo-terminal. [onExit] is called with the
/// exit code when the shell ends, [onTitleChange] when the shell sets the
/// window title. [close] ends the shell.
class TomTerminalSession {
  /// Starts [options]' shell, through [start] when given (else in a
  /// pseudo-terminal).
  TomTerminalSession({
    this.options = const TomTerminalOptions(),
    TomTerminalProcessStarter? start,
    this.onExit,
    this.onTitleChange,
  }) : terminal = Terminal(maxLines: options.scrollback) {
    shell = options.effectiveShell;
    terminal.resize(options.columns, options.rows);
    _process = (start ?? TomPtyProcess.start)(options);

    _outputSub = _process.output.listen((data) {
      if (_isClosed) return;
      _emit(utf8.decode(data, allowMalformed: true));
    });

    terminal.onOutput = (data) {
      if (_isClosed) return;
      _process.write(Uint8List.fromList(utf8.encode(data)));
    };

    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (_isClosed) return;
      _process.resize(height, width);
    };

    terminal.onTitleChange = (title) {
      if (_isClosed) return;
      _title.value = title;
      onTitleChange?.call(title);
    };

    _process.exitCode.then((code) {
      _exitCode = code;
      if (!_isClosed && options.exitMessage) {
        _emit('\r\n[Process exited with code $code]\r\n');
      }
      onExit?.call(code);
      if (!_exited.isCompleted) _exited.complete(code);
    });
  }

  /// What was started.
  final TomTerminalOptions options;

  /// The shell that runs ([TomTerminalOptions.effectiveShell]).
  late final String shell;

  /// The terminal model a [TomTerminalView] shows.
  final Terminal terminal;

  /// Called with the exit code when the shell ends.
  final void Function(int exitCode)? onExit;

  /// Called when the shell sets the window title.
  final void Function(String title)? onTitleChange;

  late final TomTerminalProcess _process;
  StreamSubscription<Uint8List>? _outputSub;
  final StreamController<String> _output = StreamController<String>.broadcast();
  final ValueNotifier<String> _title = ValueNotifier<String>('');
  final Completer<int> _exited = Completer<int>();
  int? _exitCode;
  bool _isClosed = false;

  /// What the shell writes, decoded, as it arrives (and the exit message).
  Stream<String> get output => _output.stream;

  /// The window title the shell set last; empty until it sets one.
  ValueListenable<String> get title => _title;

  /// Completes with the exit code when the shell ends.
  Future<int> get exitCode => _exited.future;

  /// The exit code once the shell ended, else null.
  int? get exitCodeOrNull => _exitCode;

  /// Whether the shell ended.
  bool get hasExited => _exitCode != null;

  /// Whether [close] was called.
  bool get isClosed => _isClosed;

  /// The process id of the shell.
  int get pid => _process.pid;

  /// The terminal's lines (scrollback included) as plain text, one line per
  /// row, trailing blanks trimmed.
  String get text {
    final lines = terminal.buffer.lines;
    return [
      for (var i = 0; i < lines.length; i++) lines[i].getText().trimRight(),
    ].join('\n').trimRight();
  }

  /// Writes [data] to the shell's input as it is.
  void write(String data) {
    if (_isClosed) return;
    _process.write(Uint8List.fromList(utf8.encode(data)));
  }

  /// Sends [text] to the shell, followed by a newline unless [addNewLine] is
  /// false.
  void sendText(String text, {bool addNewLine = true}) =>
      write(addNewLine ? '$text\n' : text);

  /// Clears the terminal and puts the cursor home.
  void clear() {
    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);
  }

  /// Ends the shell and stops listening to it. Safe to call twice.
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _outputSub?.cancel();
    _process.kill();
    _output.close();
    _title.dispose();
  }

  void _emit(String text) {
    terminal.write(text);
    if (!_output.isClosed) _output.add(text);
  }
}

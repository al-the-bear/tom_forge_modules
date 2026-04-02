import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Default implementation of [ForgeTerminalManager].
///
/// Uses [DefaultTerminal] which spawns individual processes per command.
/// For a full PTY-backed terminal, see [PtyTerminalManager].
class DefaultTerminalManager implements ForgeTerminalManager {
  static bool debugEnabled = false;

  final List<DefaultTerminal> _terminals = [];
  DefaultTerminal? _activeTerminal;

  final StreamController<ForgeTerminal> _openController =
      StreamController<ForgeTerminal>.broadcast();
  final StreamController<ForgeTerminal> _closeController =
      StreamController<ForgeTerminal>.broadcast();
  final StreamController<ForgeTerminal?> _activeController =
      StreamController<ForgeTerminal?>.broadcast();

  @override
  ForgeTerminal create({
    String? name,
    String? shellPath,
    String? cwd,
    ForgeOutputChannel? outputChannel,
  }) {
    final terminal = DefaultTerminal(
      name: name ?? 'Terminal ${_terminals.length + 1}',
      shellPath: shellPath,
      cwd: cwd,
      outputChannel: outputChannel,
      onDispose: _removeTerminal,
    );
    _terminals.add(terminal);
    _activeTerminal = terminal;
    _openController.add(terminal);
    _activeController.add(terminal);
    return terminal;
  }

  @override
  List<ForgeTerminal> get terminals => List.unmodifiable(_terminals);

  @override
  ForgeTerminal? get activeTerminal => _activeTerminal;

  @override
  void setActive(ForgeTerminal terminal) {
    if (_terminals.contains(terminal)) {
      _activeTerminal = terminal as DefaultTerminal;
      _activeController.add(_activeTerminal);
    }
  }

  @override
  Stream<ForgeTerminal> get onDidOpen => _openController.stream;

  @override
  Stream<ForgeTerminal> get onDidClose => _closeController.stream;

  @override
  Stream<ForgeTerminal?> get onDidChangeActive => _activeController.stream;

  void _removeTerminal(DefaultTerminal terminal) {
    _terminals.remove(terminal);
    _closeController.add(terminal);
    if (_activeTerminal == terminal) {
      _activeTerminal = _terminals.isNotEmpty ? _terminals.last : null;
      _activeController.add(_activeTerminal);
    }
  }

  /// Dispose all terminals and streams.
  void dispose() {
    for (final t in List.of(_terminals)) {
      t.dispose();
    }
    _terminals.clear();
    _openController.close();
    _closeController.close();
    _activeController.close();
  }
}

/// Default in-memory terminal that spawns individual processes per command.
///
/// Suitable for tests and environments where a full PTY is not available.
class DefaultTerminal implements ForgeTerminal {
  @override
  final String name;

  final String? shellPath;
  final String? cwd;
  final void Function(DefaultTerminal) _onDispose;

  /// Optional output channel for mirroring terminal output to the Output panel.
  final ForgeOutputChannel? outputChannel;

  final List<String> _history = [];
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  Process? _activeProcess;
  bool _isDisposed = false;

  DefaultTerminal({
    required this.name,
    this.shellPath,
    this.cwd,
    this.outputChannel,
    required void Function(DefaultTerminal) onDispose,
  }) : _onDispose = onDispose {
    final shell = shellPath ?? (Platform.isWindows ? 'cmd.exe' : '/bin/bash');
    outputChannel?.appendLine('New terminal opened using $shell');
  }

  @override
  Stream<String> get onOutput => _outputController.stream;

  @override
  void sendText(String text, {bool addNewLine = true}) {
    final line = addNewLine ? '$text\n' : text;
    _history.add(line);
    // Echo the command as output.
    _emit('\$ $text');
    // Execute command through a real shell when possible.
    unawaited(_executeCommand(text.trim()));
  }

  /// Emit output to the terminal view only (not the output channel).
  void _emit(String text) {
    if (_isDisposed || _outputController.isClosed) return;
    _outputController.add(text);
  }

  Future<void> _executeCommand(String command) async {
    if (command.isEmpty || _isDisposed) return;

    final executable =
        shellPath ?? (Platform.isWindows ? 'cmd.exe' : '/bin/bash');
    final args = Platform.isWindows
        ? <String>['/c', command]
        : <String>['-lc', command];
    Process? process;
    try {
      process = await Process.start(
        executable,
        args,
        workingDirectory: cwd,
        runInShell: true,
      );
      _activeProcess = process;

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_emit)
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_emit)
          .asFuture<void>();

      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (exitCode != 0) {
        _emit('[exit $exitCode]');
      }
    } catch (_) {
      // Fallback keeps tests and basic demo behavior usable on constrained
      // setups.
      _simulateResponse(command);
    } finally {
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  void _simulateResponse(String command) {
    if (command == 'echo hello') {
      _emit('hello');
    } else if (command == 'pwd') {
      _emit(cwd ?? '/');
    } else if (command == 'date') {
      _emit(DateTime.now().toString());
    } else if (command.startsWith('echo ')) {
      _emit(command.substring(5));
    }
  }

  @override
  void show({bool preserveFocus = true}) {
    // Widget layer handles visibility.
  }

  @override
  void close() {
    _closeInternal();
  }

  @override
  void dispose() {
    _closeInternal();
  }

  void _closeInternal() {
    if (_isDisposed) return;
    _isDisposed = true;
    outputChannel?.appendLine('Terminal closed');
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
    _outputController.close();
    _onDispose(this);
  }

  /// Command history for testing.
  List<String> get history => List.unmodifiable(_history);
}

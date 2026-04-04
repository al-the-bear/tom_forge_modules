import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:xterm/xterm.dart';

/// PTY-backed terminal manager for desktop platforms.
///
/// Creates [PtyTerminal] instances that spawn real pseudo-terminal sessions
/// using [flutter_pty] and render via [xterm]'s [Terminal] model.
class PtyTerminalManager implements ForgeTerminalManager {
  final List<PtyTerminal> _terminals = [];
  PtyTerminal? _activeTerminal;

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
    final terminal = PtyTerminal(
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
      _activeTerminal = terminal as PtyTerminal;
      _activeController.add(_activeTerminal);
    }
  }

  @override
  Stream<ForgeTerminal> get onDidOpen => _openController.stream;

  @override
  Stream<ForgeTerminal> get onDidClose => _closeController.stream;

  @override
  Stream<ForgeTerminal?> get onDidChangeActive => _activeController.stream;

  @override
  void detach(ForgeTerminal terminal) {
    if (terminal is! PtyTerminal) return;
    _terminals.remove(terminal);
    _closeController.add(terminal);
    if (_activeTerminal == terminal) {
      _activeTerminal = _terminals.isNotEmpty ? _terminals.last : null;
      _activeController.add(_activeTerminal);
    }
  }

  void _removeTerminal(PtyTerminal terminal) {
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

/// A full PTY-backed terminal using [flutter_pty] and [xterm].
///
/// Spawns a real pseudo-terminal session (bash/zsh/cmd) with full ANSI/VT100
/// support, interactive commands, job control, and proper TTY emulation.
class PtyTerminal implements ForgeTerminal {
  @override
  final String name;

  /// The xterm [Terminal] model that drives the [TerminalView] widget.
  ///
  /// Use this in the view layer to render a fully-featured terminal emulator.
  final Terminal terminalModel;

  final ForgeOutputChannel? outputChannel;
  final void Function(PtyTerminal) _onDispose;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  StreamSubscription<Uint8List>? _ptyOutputSub;

  late final Pty _pty;
  bool _isDisposed = false;

  PtyTerminal({
    required this.name,
    String? shellPath,
    String? cwd,
    this.outputChannel,
    required void Function(PtyTerminal) onDispose,
  })  : _onDispose = onDispose,
        terminalModel = Terminal(maxLines: 10000) {
    final shell = shellPath ?? _defaultShell();

    _pty = Pty.start(
      shell,
      workingDirectory: cwd,
      columns: 80,
      rows: 25,
    );

    // Log lifecycle event: terminal opened.
    outputChannel?.appendLine('New terminal opened using $shell');

    // Wire PTY output → xterm Terminal model + onOutput stream.
    _ptyOutputSub = _pty.output.listen((data) {
      if (_isDisposed) return;
      final text = utf8.decode(data, allowMalformed: true);
      terminalModel.write(text);
      // Mirror to onOutput stream only (not output channel).
      if (!_outputController.isClosed) {
        _outputController.add(text);
      }
    });

    // Wire xterm Terminal user input → PTY stdin.
    terminalModel.onOutput = (data) {
      if (_isDisposed) return;
      _pty.write(Uint8List.fromList(utf8.encode(data)));
    };

    // Wire xterm Terminal resize → PTY resize.
    terminalModel.onResize = (width, height, pixelWidth, pixelHeight) {
      if (_isDisposed) return;
      _pty.resize(height, width);
    };

    // Handle PTY process exit.
    _pty.exitCode.then((code) {
      if (!_isDisposed && !_outputController.isClosed) {
        final exitMsg = '\r\n[Process exited with code $code]\r\n';
        terminalModel.write(exitMsg);
        _outputController.add(exitMsg);
      }
      outputChannel?.appendLine('Terminal process exited with code $code');
    });
  }

  static String _defaultShell() {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    }
    return Platform.environment['SHELL'] ?? '/bin/bash';
  }

  @override
  Stream<String> get onOutput => _outputController.stream;

  @override
  void sendText(String text, {bool addNewLine = true}) {
    if (_isDisposed) return;
    final data = addNewLine ? '$text\n' : text;
    _pty.write(Uint8List.fromList(utf8.encode(data)));
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
    _ptyOutputSub?.cancel();
    _pty.kill();
    _outputController.close();
    _onDispose(this);
  }
}

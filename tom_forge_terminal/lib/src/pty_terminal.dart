import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_terminal_view/tom_terminal_view.dart';

/// PTY-backed terminal manager for desktop platforms.
///
/// Creates [PtyTerminal] instances, each a shell in a pseudo-terminal
/// ([TomTerminalSession] of `tom_terminal_view`).
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

/// A full PTY-backed terminal: Forge's [ForgeTerminal] over a
/// [TomTerminalSession] (`tom_terminal_view`).
///
/// Spawns a real pseudo-terminal session (bash/zsh/cmd) with full ANSI/VT100
/// support, interactive commands, job control, and proper TTY emulation; the
/// terminal's [outputChannel] gets its opening, exit and closing.
class PtyTerminal implements ForgeTerminal {
  @override
  final String name;

  /// The shell's session, which a [TomTerminalView] shows.
  late final TomTerminalSession session;

  final ForgeOutputChannel? outputChannel;
  final void Function(PtyTerminal) _onDispose;

  bool _isDisposed = false;

  PtyTerminal({
    required this.name,
    String? shellPath,
    String? cwd,
    this.outputChannel,
    required void Function(PtyTerminal) onDispose,
  }) : _onDispose = onDispose {
    session = TomTerminalSession(
      options: TomTerminalOptions(shell: shellPath, workingDirectory: cwd),
      onExit: (code) =>
          outputChannel?.appendLine('Terminal process exited with code $code'),
    );
    // Log lifecycle event: terminal opened.
    outputChannel?.appendLine('New terminal opened using ${session.shell}');
  }

  /// The xterm [Terminal] model of [session], which drives the view.
  Terminal get terminalModel => session.terminal;

  @override
  Stream<String> get onOutput => session.output;

  @override
  void sendText(String text, {bool addNewLine = true}) {
    if (_isDisposed) return;
    session.sendText(text, addNewLine: addNewLine);
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
    session.close();
    _onDispose(this);
  }
}

/// Forge's terminal: PTY-backed terminals (a [TomTerminalSession] of
/// `tom_terminal_view`, the shell and the xterm widget without Forge) and
/// process-backed ones, and the view a terminal is shown in, as
/// [ForgeShellComponents] for a shell ([forgeTerminalComponents]), and the
/// module that places the terminals ([forgeTerminalModule]).
library;

// The type of PtyTerminal.session.
export 'package:tom_terminal_view/tom_terminal_view.dart'
    show TomTerminalSession;

export 'src/default_terminal_manager.dart';
export 'src/forge_terminal_module.dart';
export 'src/forge_terminal_view.dart';
export 'src/pty_terminal.dart';
export 'src/terminal_components.dart';

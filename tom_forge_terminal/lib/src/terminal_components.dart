import 'package:tom_file_system/io.dart' show TomLocalFileSystem;
import 'package:tom_forge_shell/tom_forge_shell.dart';

import 'default_terminal_manager.dart';
import 'forge_terminal_view.dart';
import 'pty_terminal.dart';

/// The terminal as [ForgeShellComponents]: PTY-backed terminals
/// ([PtyTerminalManager]) for a shell over a folder on disk, process-backed
/// ones ([DefaultTerminalManager]) otherwise, each shown in a
/// [SingleTerminalView].
final ForgeShellComponents forgeTerminalComponents = ForgeShellComponents(
  terminalManager: (fileSystem) => fileSystem is TomLocalFileSystem
      ? PtyTerminalManager()
      : DefaultTerminalManager(),
  terminalView: (terminal) => SingleTerminalView(terminal: terminal),
);

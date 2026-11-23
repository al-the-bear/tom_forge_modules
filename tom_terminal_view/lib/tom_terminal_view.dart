/// A terminal for any Flutter UI: a shell in a pseudo-terminal
/// ([TomTerminalSession] over `flutter_pty`) and the widget that shows it
/// ([TomTerminalView], the `xterm` fork's view), with plain types for what
/// is started ([TomTerminalOptions]) and how it looks ([TomTerminalStyle],
/// [TomTerminalColors]).
///
/// ```dart
/// final session = TomTerminalSession(
///   options: const TomTerminalOptions(workingDirectory: '/Users/me'),
///   onExit: (code) => debugPrint('shell ended: $code'),
/// );
/// // ... in a build method:
/// TomTerminalView(session: session);
/// // ... when done:
/// session.close();
/// ```
///
/// [Terminal] is xterm's terminal model, the type of
/// [TomTerminalSession.terminal].
library;

export 'package:xterm/xterm.dart' show Terminal;

export 'src/terminal_session.dart';
export 'src/terminal_style.dart';
export 'src/terminal_view.dart';

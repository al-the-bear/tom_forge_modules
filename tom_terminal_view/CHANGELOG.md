# Changelog

## 0.1.0

- `TomTerminalSession`: a shell in a pseudo-terminal (`flutter_pty`) with the
  xterm terminal model it writes into; `TomTerminalOptions` (shell,
  arguments, working directory, environment, size, scrollback, exit
  message), `output`, `title`, `exitCode`, `write`, `sendText`, `clear`,
  `text`, `close`, and `onExit` / `onTitleChange`. `TomTerminalProcess` is
  the process it talks to (`TomPtyProcess` by default; a test gives its own).
- `TomTerminalView`: the widget that shows a session (the `xterm` fork's
  view) and forwards the keys to it; `TomTerminalStyle` (font family and
  size) and `TomTerminalColors` (text, background, cursor, selection, the 16
  ANSI colours).

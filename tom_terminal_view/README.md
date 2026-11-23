# Tom Terminal View

A terminal for any Flutter UI: a shell running in a pseudo-terminal
(`TomTerminalSession`, over `flutter_pty`) and the widget that shows it
(`TomTerminalView`, over the `xterm` fork). It knows nothing of Tom Forge;
Forge's terminal (`tom_forge_terminal`) is an adapter over it.

Desktop platforms (macOS, Linux, Windows): `flutter_pty` is an FFI plugin
whose native library the Flutter build bundles with the app.

## Embedding it

Add the dependency (a path or git dependency; the package is not on pub.dev)
and the `xterm` fork it builds on, as in this package's `pubspec.yaml`. Then
start a session and show it:

```dart
import 'package:flutter/material.dart';
import 'package:tom_terminal_view/tom_terminal_view.dart';

class ShellPane extends StatefulWidget {
  const ShellPane({super.key});

  @override
  State<ShellPane> createState() => _ShellPaneState();
}

class _ShellPaneState extends State<ShellPane> {
  late final TomTerminalSession _session = TomTerminalSession(
    options: const TomTerminalOptions(
      // null: the user's $SHELL (%COMSPEC% on Windows).
      shell: '/bin/zsh',
      workingDirectory: '/Users/me/projects',
      environment: {'MY_VAR': '1'},
      scrollback: 5000,
    ),
    onExit: (code) => debugPrint('shell ended with $code'),
    onTitleChange: (title) => debugPrint('title: $title'),
  );

  @override
  void dispose() {
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TomTerminalView(
    session: _session,
    style: TomTerminalStyle(
      fontFamily: 'Menlo',
      fontSize: 13,
      colors: TomTerminalColors.standard.copyWith(
        background: const Color(0xFF1E1E1E),
      ),
    ),
  );
}
```

What the session offers besides the view:

- `sendText('ls -la')` (with a newline) and `write(data)` (as it is) send to
  the shell;
- `output` streams what the shell writes, `text` is the terminal's lines as
  plain text, `title` the window title the shell set;
- `exitCode`, `hasExited` and `onExit` tell when the shell ended, `close()`
  ends it;
- `clear()` clears the terminal; `terminal` is xterm's `Terminal` model for
  anything else.

The view takes the focus when it appears (`autofocus`) and on a tap, and
forwards every key to the terminal itself, so typing reaches the shell inside
hosts whose own focus handling competes for keys. It resizes the
pseudo-terminal to its size.

A test, or a host with a process of its own, passes `start:` a function that
returns a `TomTerminalProcess`.

## Tests

`flutter test` runs the unit tests over a fake process and a widget test that
runs a real `/bin/sh` in the view. `flutter test` does not build the plugin's
native library, so the widget test compiles `flutter_pty`'s C source with
`clang` into `build/test_native/` first (`test/support/pty_native_library.dart`);
without `clang` it is skipped.

## License

BSD-3-Clause; see [LICENSE](LICENSE).

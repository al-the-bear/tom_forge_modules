// `flutter test` runs `testExecutable` before every suite of this package:
// it registers Forge's desktop components — the terminal, the Dart adapter's
// editor type, the keychain and the desktop host — for every shell the
// suites make, as an application does at start, composed from the shell
// parts themselves. Without it a shell has only the shell core's (no
// terminals, files opened as plain text). The Markdown and YAML adapters are
// not this package's: its suites register file kinds of their own.

import 'dart:async';

import 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
import 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
import 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show ForgeShellComponents;
import 'package:tom_forge_terminal/tom_forge_terminal.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ForgeShellComponents.register(
    forgeTerminalComponents
        .mergedWith(ForgeShellComponents(editorTypes: [forgeDartEditorType]))
        .mergedWith(forgePlatformSecretComponents)
        .mergedWith(forgeDesktopHostComponents),
  );
  await testMain();
}

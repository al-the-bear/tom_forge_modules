// `flutter test` runs `testExecutable` before every suite of this package:
// it registers Forge's desktop components — the terminal, the code editors
// (Markdown, Dart, YAML), the keychain and the desktop host — for every shell
// the suites make, as an application does at start, composed from the shell
// parts themselves (what the umbrella's `forgeDesktopComponents` is). Without
// it a shell has only the shell core's (no terminals, files opened as plain
// text).

import 'dart:async';

import 'package:tom_forge_code_editors/tom_forge_code_editors.dart';
import 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
import 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show ForgeShellComponents;
import 'package:tom_forge_terminal/tom_forge_terminal.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ForgeShellComponents.register(
    forgeTerminalComponents
        .mergedWith(forgeCodeEditorComponents)
        .mergedWith(forgePlatformSecretComponents)
        .mergedWith(forgeDesktopHostComponents),
  );
  await testMain();
}

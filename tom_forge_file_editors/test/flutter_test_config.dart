// `flutter test` runs `testExecutable` before every suite of this package:
// it registers Forge's desktop components — the terminal, the code editors
// (Markdown, Dart, YAML), the keychain — for every shell the suites make, as
// an application does at start. Without it a shell has only the shell core's
// (no terminals, files opened as plain text).

import 'dart:async';

import 'package:tom_forge_ui/tom_forge_ui.dart' show useForgeDesktopComponents;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useForgeDesktopComponents();
  await testMain();
}

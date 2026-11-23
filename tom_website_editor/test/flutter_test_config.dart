// `flutter test` runs `testExecutable` before every suite of this package:
// it registers Forge's desktop components — the terminal, the editor types
// of the Markdown, Dart and YAML adapters, the keychain and the desktop
// host — for every shell the suites make, as an application does at start,
// composed from the shell parts themselves (what the umbrella's
// `forgeDesktopComponents` is). Without it a shell has only the shell core's
// (no terminals, files opened as plain text).

import 'dart:async';

import 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
import 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show ForgeShellComponents;
import 'package:tom_forge_terminal/tom_forge_terminal.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ForgeShellComponents.register(
    forgeTerminalComponents
        .mergedWith(
          ForgeShellComponents(
            editorTypes: [
              forgeMarkdownEditorType,
              forgeDartEditorType,
              forgeYamlEditorType,
            ],
          ),
        )
        .mergedWith(forgePlatformSecretComponents)
        .mergedWith(forgeDesktopHostComponents),
  );
  await testMain();
}

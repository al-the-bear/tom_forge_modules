import 'package:flutter/material.dart';
import 'package:tom_file_system/io.dart';

import 'src/lite_launch.dart';
import 'src/lite_shell.dart';

export 'src/lite_launch.dart';
export 'src/lite_shell.dart';
export 'src/sample_workspace.dart';

/// The light panel shell example: the workspace folder the command line
/// names (else the current directory, else the bundled sample folder) in
/// Forge's panel shell, with the file explorer and the YAML editor.
void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final launch = LiteLaunch.parse(arguments)..applyTrails();
  final root = launch.resolveWorkspace();
  final lite = LiteForgeShell.compose(
    fileSystem: TomLocalFileSystem(root),
    workspaceRoot: root,
  );
  runApp(LiteForgeApp(lite: lite));
}

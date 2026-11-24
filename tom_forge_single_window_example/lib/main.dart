import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_file_system/io.dart';

import 'src/kit_launch.dart';
import 'src/kit_yaml_tool.dart';
import 'src/kit_yaml_window.dart';

export 'src/kit_launch.dart';
export 'src/kit_yaml_tool.dart';
export 'src/kit_yaml_window.dart';
export 'src/sample_file.dart';
export 'src/single_window_host.dart';

/// The single-window example: the YAML file the command line names (else
/// the sample file) in a window of its own, on the kit and the shared look
/// only.
void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  final launch = KitLaunch.parse(arguments)..applyTrails();
  final file = launch.resolveFile();
  final tool = KitYamlTool.compose(
    fileSystem: TomLocalFileSystem(file.parent.path),
  );
  runApp(KitYamlApp(tool: tool));
  unawaited(tool.restore().then((_) => tool.open(file.uri)));
}

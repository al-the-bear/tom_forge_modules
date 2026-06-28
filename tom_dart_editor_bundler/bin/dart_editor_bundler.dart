#!/usr/bin/env dart
/// tom_dart_editor_bundler CLI (dart-editor-bundler).
///
/// Builds the summary `.sum` bundles and the generated scope-init helper for the
/// tom_dart_editor embedded code editor. Run with `--help` for usage.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';

import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';

Future<void> main(List<String> args) async {
  final runner = ToolRunner(
    tool: dartEditorBundlerTool,
    executors: createDartEditorBundlerExecutors(),
  );

  final result = await runner.run(args);

  if (!result.success) {
    exitCode = 1;
  }
}

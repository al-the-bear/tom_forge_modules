// ignore_for_file: avoid_print

/// Builds `assets/sdk_summary.sum`: the analyzer summary of the Dart SDK this
/// script runs on (the plain SDK, without Flutter's `dart:ui`: types Flutter
/// re-exports from it do not resolve in the editor yet, tom_forge
/// later14_akga-dart-ui-in-editor-summaries). The summary's format is
/// the analyzer's, so it is rebuilt whenever the analyzer major changes —
/// with `build_packages_summary.dart`, and both copied to every app that
/// ships them (`tom_forge/tom_dart_editor/doc/package_summary_generation.md`).
///
///     dart run tool/build_sdk_summary.dart [output]

library;

import 'dart:io';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

Future<void> main(List<String> args) async {
  final output = args.isNotEmpty ? args[0] : 'assets/sdk_summary.sum';
  // <sdk>/bin/dart(.exe) -> <sdk>
  final sdkPath = File(Platform.resolvedExecutable).parent.parent.path;
  print('SDK: $sdkPath (Dart ${Platform.version.split(' ').first})');
  final bytes = await buildSdkSummary(
    resourceProvider: PhysicalResourceProvider.INSTANCE,
    sdkPath: sdkPath,
  );
  File(output).writeAsBytesSync(bytes);
  print('Wrote $output (${bytes.length} bytes)');
}

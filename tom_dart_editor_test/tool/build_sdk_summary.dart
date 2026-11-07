// ignore_for_file: avoid_print

/// Builds `assets/sdk_summary.sum`: the analyzer summary of the Dart SDK this
/// script runs on with Flutter's embedder libraries added (`dart:ui` and what
/// it needs; `tool/flutter_sdk.dart`) — the SDK `build_packages_summary.dart`
/// links the package summary against. Run it with the `dart` of the Flutter
/// whose `dart:ui` is wanted, after `flutter pub get`. The summary's format is
/// the analyzer's, so it is rebuilt whenever the analyzer major changes —
/// with `build_packages_summary.dart`, and both copied to every app that
/// ships them (`tom_forge/tom_dart_editor/doc/package_summary_generation.md`).
///
///     dart run tool/build_sdk_summary.dart [output]

library;

import 'dart:io';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

import 'flutter_sdk.dart';

Future<void> main(List<String> args) async {
  final output = args.isNotEmpty ? args[0] : 'assets/sdk_summary.sum';
  final sdkPath = runningSdkPath();
  final embedder = flutterEmbedderYamlPath();
  print('SDK: $sdkPath (Dart ${Platform.version.split(' ').first})');
  print('Embedder: $embedder');
  final bytes = await buildSdkSummary(
    resourceProvider: PhysicalResourceProvider.INSTANCE,
    sdkPath: sdkPath,
    embedderYamlPath: embedder,
  );
  File(output).writeAsBytesSync(bytes);
  print('Wrote $output (${bytes.length} bytes)');
}

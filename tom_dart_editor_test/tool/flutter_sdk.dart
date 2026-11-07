/// The SDK both summary tools build against: the Dart SDK the tool runs on
/// with the libraries of Flutter's embedder added (`dart:ui`, `dart:ui_web`
/// and what they need), as Flutter's own analysis sees it. Both summaries
/// must be built against the same SDK — `packages.sum` is linked against it,
/// and Flutter's `export 'dart:ui' show ...` lines resolve only when the SDK
/// it is linked against holds `dart:ui`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/file_system/file_system.dart' show ResourceProvider;
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:yaml/yaml.dart';

/// The Dart SDK of the running `dart` (`<sdk>/bin/dart` -> `<sdk>`).
String runningSdkPath() => File(Platform.resolvedExecutable).parent.parent.path;

/// Flutter's embedder file, `<sky_engine>/lib/_embedder.yaml`, found through
/// this package's `.dart_tool/package_config.json` (run `flutter pub get`
/// with the Flutter whose summaries are wanted).
String flutterEmbedderYamlPath() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    throw StateError('Run "flutter pub get" first: no ${config.path}');
  }
  final packages =
      (jsonDecode(config.readAsStringSync()) as Map<String, dynamic>)['packages']
          as List<dynamic>;
  for (final package in packages.cast<Map<String, dynamic>>()) {
    if (package['name'] != 'sky_engine') continue;
    final root = Uri.parse(package['rootUri'] as String).toFilePath();
    final yaml = File('$root/lib/_embedder.yaml');
    if (yaml.existsSync()) return yaml.path;
    throw StateError('sky_engine has no ${yaml.path}');
  }
  throw StateError(
    'No sky_engine in ${config.path}: the summaries are built in a Flutter '
    'package',
  );
}

/// The SDK at [sdkPath] with the embedder's libraries added that it lacks —
/// what `buildSdkSummary(embedderYamlPath: ...)` builds the SDK summary
/// from, so the package summary is linked against the same libraries.
FolderBasedDartSdk sdkWithEmbedder(
  ResourceProvider resourceProvider, {
  required String sdkPath,
  required String embedderYamlPath,
}) {
  final sdk = FolderBasedDartSdk(
    resourceProvider,
    resourceProvider.getFolder(sdkPath),
  );
  final file = resourceProvider.getFile(embedderYamlPath);
  final embedder = EmbedderSdk.new2(
    resourceProvider,
    file.parent,
    loadYaml(file.readAsStringSync()) as YamlMap,
    languageVersion: sdk.languageVersion,
  );
  for (final library in embedder.sdkLibraries) {
    if (sdk.libraryMap.getLibrary(library.shortName) == null) {
      sdk.libraryMap.setLibrary(library.shortName, library);
    }
  }
  return sdk;
}

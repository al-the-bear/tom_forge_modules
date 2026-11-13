// ignore_for_file: avoid_print

// Diagnostic tool: reads packages.sum and dumps its contents.
// Run: dart run tool/diagnose_packages_sum.dart [path_to_packages.sum]
//
// This verifies that the binary bundle contains the expected library and unit
// URIs so that InSummaryUriResolver can resolve them at runtime.

import 'dart:io';

import 'package:analyzer/src/summary2/package_bundle_format.dart';
import 'package:analyzer/src/summary/package_bundle_reader.dart';

void main(List<String> args) {
  final path =
      args.isNotEmpty ? args[0] : 'assets/summaries/dart-editor/packages.sum';
  final file = File(path);
  if (!file.existsSync()) {
    print('ERROR: File not found: $path');
    exit(1);
  }

  final bytes = file.readAsBytesSync();
  print('File: $path');
  print('Size: ${bytes.length} bytes\n');

  // Parse the bundle
  final bundle = PackageBundleReader(bytes);
  print('Libraries: ${bundle.libraries.length}');
  print('Resolution bytes: ${bundle.resolutionBytes.length} bytes');
  try {
    print('SDK: ${bundle.sdk != null ? "present" : "absent"}');
  } catch (_) {
    print('SDK: not initialized (non-SDK bundle)');
  }
  print('');

  // Dump each library and its units
  for (var i = 0; i < bundle.libraries.length; i++) {
    final lib = bundle.libraries[i];
    print('Library $i: "${lib.uriStr}"');
    print('  Units (${lib.units.length}):');
    for (var j = 0; j < lib.units.length; j++) {
      print('    [$j] "${lib.units[j].uriStr}"');
    }
  }

  // Now simulate what SummaryDataStore.addBundle does
  print('\n--- SummaryDataStore simulation ---');
  final dataStore = SummaryDataStore();
  dataStore.addBundle('packages', bundle);

  // Apply the same workaround as analyzer_with_packages.dart
  for (var library in bundle.libraries) {
    var libraryUri = library.uriStr;
    if (!dataStore.uriToSummaryPath.containsKey(libraryUri)) {
      dataStore.uriToSummaryPath[libraryUri] = 'packages';
    }
  }

  print('uriToSummaryPath entries: ${dataStore.uriToSummaryPath.length}');
  for (final entry in dataStore.uriToSummaryPath.entries) {
    print('  "${entry.key}" -> "${entry.value}"');
  }

  print('\nhasLinkedLibrary checks:');
  for (final testUri in [
    'package:tom_dcli/dcli.dart',
    'package:path/path.dart',
    'package:dcli_core/dcli_core.dart',
  ]) {
    print('  $testUri -> ${dataStore.hasLinkedLibrary(testUri)}');
  }

  print('\nhasUnlinkedUnit checks:');
  for (final testUri in [
    'package:tom_dcli/dcli.dart',
    'package:path/path.dart',
    'package:dcli_core/dcli_core.dart',
  ]) {
    print('  $testUri -> ${dataStore.hasUnlinkedUnit(testUri)}');
  }
}

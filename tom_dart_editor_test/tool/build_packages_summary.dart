// ignore_for_file: avoid_print

// Tool to build package summary for bundling with the app.
//
// Run: dart run tool/build_packages_summary.dart [output_path]
//
// Builds a summary for the packages used in implicit imports:
//   - package:dcli/dcli.dart
//   - package:path/path.dart
//
// Uses ~/.pub-cache and the local .dart_tool/package_config.json to resolve.

import 'dart:convert';
import 'dart:io' as io;

// Import analyzer File system — use 'show' to avoid shadowing dart:io types.
import 'package:analyzer/file_system/file_system.dart'
    show Folder, ResourceProvider;
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/file_source.dart' show FileSource;
import 'package:analyzer/source/source.dart' show Source;
import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/analysis_options/analysis_options.dart';
import 'package:analyzer/src/dart/analysis/analysis_options_map.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:analyzer/src/file_system/file_system.dart'
    show ResourceUriResolver;
import 'package:analyzer/src/generated/source.dart'
    show DartUriResolver, SourceFactory, UriResolver;
import 'package:analyzer/src/util/sdk.dart';
import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final outputPath = args.isNotEmpty ? args[0] : 'assets/packages.sum';

  final resourceProvider = PhysicalResourceProvider.INSTANCE;

  // Get SDK path
  final sdkPath = getSdkPath();
  print('Using SDK: $sdkPath');

  // Read package_config.json to find installed packages
  final packageConfigFile = io.File('.dart_tool/package_config.json');
  if (!packageConfigFile.existsSync()) {
    print(
        'ERROR: Run "dart pub get" first to generate .dart_tool/package_config.json');
    io.exit(1);
  }

  final packageConfig =
      jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
  final packageList = packageConfig['packages'] as List<dynamic>;

  // Build a map of package name -> root path
  final packageRoots = <String, String>{};
  for (final pkg in packageList) {
    final pkgMap = pkg as Map<String, dynamic>;
    final name = pkgMap['name'] as String;
    final rootUri = pkgMap['rootUri'] as String;
    // Convert file:// URI to path
    final root = Uri.parse(rootUri).toFilePath();
    packageRoots[name] = root;
  }

  print('Found ${packageRoots.length} packages in config');

  // Packages whose top-level lib/ files are the primary targets.
  final primaryPackages = [
    'dcli',
    'path',
    'dcli_core',
    'dcli_common',
    'dcli_terminal',
  ];

  // Build the Packages object for analysis
  final packages = Packages({
    for (final entry in packageRoots.entries)
      entry.key: Package(
        name: entry.key,
        rootFolder: resourceProvider.getFolder(entry.value),
        libFolder: resourceProvider.getFolder(p.join(entry.value, 'lib')),
        languageVersion: null,
      ),
  });

  // Build package URI list.
  // Include ALL packages (not just primary targets) so that transitive
  // dependencies are also serialized into the bundle.  Without these,
  // the BundleReader cannot resolve type references from the primary
  // libraries to types defined in their dependencies.
  //
  // IMPORTANT: We list ALL .dart files recursively (including src/ dirs),
  // not just top-level lib/ files.  The resolution bytes for a library
  // reference all imported/exported URIs.  If an internal file like
  // package:dcli/src/functions/ask.dart is not in the bundle as a
  // library entry, the consumer's InSummaryUriResolver can't resolve it
  // and deserialization fails with a null check error.
  final libraryUris = <Uri>[];

  for (final entry in packageRoots.entries) {
    final pkgName = entry.key;
    final pkgRoot = entry.value;

    final libDir = io.Directory(p.join(pkgRoot, 'lib'));
    if (!libDir.existsSync()) continue;

    int count = 0;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is io.File && entity.path.endsWith('.dart')) {
        // Build the package: URI from the relative path under lib/
        final relativePath = p.relative(entity.path, from: libDir.path);
        // Ensure forward slashes for URIs (matters on Windows)
        final uriPath = relativePath.replaceAll('\\', '/');
        libraryUris.add(Uri.parse('package:$pkgName/$uriPath'));
        count++;
      }
    }
    if (count > 0) {
      final isPrimary = primaryPackages.contains(pkgName);
      print('  $pkgName: $count dart files${isPrimary ? " (primary)" : ""}');
    }
  }

  print('\nTotal libraries to summarize: ${libraryUris.length}');
  if (libraryUris.isEmpty) {
    print('ERROR: No libraries found to summarize');
    io.exit(1);
  }

  // Build SDK first (needed by the analysis driver)
  print('\nBuilding SDK summary...');
  final sdkSummaryBytes = await buildSdkSummary(
    resourceProvider: resourceProvider,
    sdkPath: sdkPath,
  );
  print('SDK summary: ${sdkSummaryBytes.length} bytes');

  // Set up the analysis driver with SDK + package resolvers
  final sdk = FolderBasedDartSdk(
    resourceProvider,
    resourceProvider.getFolder(sdkPath),
  );

  final logger = PerformanceLog(StringBuffer());
  final scheduler = AnalysisDriverScheduler(logger);
  final byteStore = MemoryByteStore();
  final optionsMap = AnalysisOptionsMap.forSharedOptions(AnalysisOptionsImpl());

  // Source factory: SDK resolver + package resolver using installed packages.
  // IMPORTANT: _PackageMapUriResolver MUST come before ResourceUriResolver.
  // When the analyzer builds the bundle, it calls pathToUri() to determine
  // the canonical URI stored in the resolution bytes. If ResourceUriResolver
  // is first, it wins and stores file:// URIs instead of package: URIs,
  // making the bundle non-portable and breaking InSummaryUriResolver lookups
  // at the consumer side.
  final sourceFactory = SourceFactory([
    DartUriResolver(sdk),
    _PackageMapUriResolver(resourceProvider, {
      for (final entry in packageRoots.entries)
        entry.key: resourceProvider.getFolder(p.join(entry.value, 'lib')),
    }),
    ResourceUriResolver(resourceProvider),
  ]);

  final analysisDriver = AnalysisDriver(
    scheduler: scheduler,
    logger: logger,
    resourceProvider: resourceProvider,
    byteStore: byteStore,
    sourceFactory: sourceFactory,
    analysisOptionsMap: optionsMap,
    packages: packages,
    withFineDependencies: false,
  );
  scheduler.start();

  // Build the package bundle
  print('\nBuilding package bundle...');
  final sw = Stopwatch()..start();

  try {
    final bytes = await analysisDriver.buildPackageBundle(
      uriList: libraryUris,
    );

    final outputFile = io.File(outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsBytesSync(bytes);
    print('Done in ${sw.elapsedMilliseconds}ms');
    print('Output: ${outputFile.absolute.path} (${bytes.length} bytes)');
  } catch (e, s) {
    print('ERROR building package bundle: $e');
    print(s);
    io.exit(1);
  }
}

/// A UriResolver that maps package: URIs to file system paths.
class _PackageMapUriResolver extends UriResolver {
  final ResourceProvider _resourceProvider;
  final Map<String, Folder> _packageMap;

  _PackageMapUriResolver(this._resourceProvider, this._packageMap);

  @override
  Uri? pathToUri(String path) {
    for (final entry in _packageMap.entries) {
      final pkgPath = entry.value.path;
      if (path.startsWith(pkgPath)) {
        final relative = path.substring(pkgPath.length);
        if (relative.startsWith('/') ||
            relative.startsWith(io.Platform.pathSeparator)) {
          return Uri.parse(
              'package:${entry.key}${relative.replaceAll('\\', '/')}');
        }
      }
    }
    return null;
  }

  @override
  Source? resolveAbsolute(Uri uri) {
    if (uri.scheme != 'package') return null;
    final parts = uri.pathSegments;
    if (parts.isEmpty) return null;

    final pkgName = parts[0];
    final folder = _packageMap[pkgName];
    if (folder == null) return null;

    final relPath = parts.skip(1).join('/');
    final file = _resourceProvider.getFile('${folder.path}/$relPath');
    if (!file.exists) return null;

    return FileSource(file, uri);
  }
}

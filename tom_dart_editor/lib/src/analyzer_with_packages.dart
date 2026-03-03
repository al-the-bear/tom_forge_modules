// Example: How to use package summaries in the editor
//
// This file shows how to modify the analyzer setup to support
// external packages via pre-built package summaries.

import 'dart:typed_data';

import 'package:analyzer/dart/analysis/analysis_options.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/source/source.dart' show Source;
import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/dart/analysis/analysis_options.dart';
import 'package:analyzer/src/dart/analysis/analysis_options_map.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/summary/package_bundle_reader.dart';
import 'package:analyzer/src/summary/summary_sdk.dart';
import 'package:analyzer/src/summary2/package_bundle_format.dart';

/// Creates an analysis driver with support for both SDK and package summaries.
///
/// Usage:
/// ```dart
/// // Load summaries from assets
/// final sdkBytes = await rootBundle.load('assets/sdk_summary.sum');
/// final pkgBytes = await rootBundle.load('assets/packages.sum');
///
/// final driver = createAnalysisDriverWithPackages(
///   resourceProvider: PhysicalResourceProvider.INSTANCE,
///   sdkSummaryBytes: sdkBytes.buffer.asUint8List(),
///   packageSummaryBytes: pkgBytes.buffer.asUint8List(),
///   analysisOptions: AnalysisOptionsImpl(),
///   uriResolvers: [ResourceUriResolver(resourceProvider)],
///   packages: Packages({}),
/// );
///
/// // Now you can analyze code that uses packages like dcli, path, etc.
/// final session = driver.currentSession;
/// final errors = await session.getErrors(filePath);
/// ```
AnalysisDriverWithPackages createAnalysisDriverWithPackages({
  required ResourceProvider resourceProvider,
  required Uint8List sdkSummaryBytes,
  Uint8List? packageSummaryBytes,
  required AnalysisOptions analysisOptions,
  required List<UriResolver> uriResolvers,
  required Packages packages,
  ByteStore? byteStore,
}) {
  // Load SDK bundle
  var sdkBundle = PackageBundleReader(sdkSummaryBytes);
  var sdk = SummaryBasedDartSdk.forBundle(sdkBundle);

  // Create data store and add SDK bundle
  var dataStore = SummaryDataStore();
  dataStore.addBundle('sdk', sdkBundle);

  // Add package bundle if provided
  List<String> packageLibraryUris = [];
  if (packageSummaryBytes != null && packageSummaryBytes.isNotEmpty) {
    var packageBundle = PackageBundleReader(packageSummaryBytes);
    dataStore.addBundle('packages', packageBundle);

    // Collect library URIs from the package bundle
    packageLibraryUris =
        packageBundle.libraries.map((lib) => lib.uriStr).toList();

    // WORKAROUND: buildPackageBundle stores unit URIs as file:// paths
    // (the resolved path from the build machine's pub-cache) rather than
    // package: URIs.  SummaryDataStore.addBundle only registers unit URIs
    // in uriToSummaryPath, so package: lookups via InSummaryUriResolver
    // fail.  Explicitly register each library's package: URI so the
    // resolver can find them.
    for (var library in packageBundle.libraries) {
      var libraryUri = library.uriStr;
      if (!dataStore.uriToSummaryPath.containsKey(libraryUri)) {
        dataStore.uriToSummaryPath[libraryUri] = 'packages';
      }
    }
  }

  // Create source factory.
  // File-system resolvers (e.g. PackageMapUriResolver) must come BEFORE
  // summary resolvers so that package: URIs are mapped to real file paths
  // first. The custom PackageSummaryUriResolver acts as a comprehensive
  // fallback that resolves ANY package:X/... URI (including internal src/
  // files) as long as package X has at least one library in the bundle.
  // This is needed because the bundle's resolution bytes reference ALL
  // imported/exported URIs, and InSummaryUriResolver only resolves URIs
  // explicitly registered in uriToSummaryPath.
  var packageSummaryResolver = PackageSummaryUriResolver(dataStore);
  var sourceFactory = SourceFactory([
    DartUriResolver(sdk),
    ...uriResolvers,
    packageSummaryResolver,
  ]);

  var logger = PerformanceLog(null);
  byteStore ??= MemoryByteStore();

  var scheduler = AnalysisDriverScheduler(logger);
  scheduler.events.drain<void>().ignore();

  var sharedOptions = analysisOptions as AnalysisOptionsImpl;
  var optionsMap = AnalysisOptionsMap.forSharedOptions(sharedOptions);

  var driver = AnalysisDriver(
    scheduler: scheduler,
    logger: logger,
    resourceProvider: resourceProvider,
    byteStore: byteStore,
    sourceFactory: sourceFactory,
    analysisOptionsMap: optionsMap,
    externalSummaries: dataStore,
    packages: packages,
    shouldReportInconsistentAnalysisException: false,
    withFineDependencies: false,
  );

  scheduler.start();

  return AnalysisDriverWithPackages._(
    sdk.libraryUris,
    packageLibraryUris,
    driver,
  );
}

/// Analysis driver wrapper with package support.
class AnalysisDriverWithPackages {
  final List<Uri> _sdkLibraryUris;
  final List<String> _packageLibraryUris;
  final AnalysisDriver _driver;

  AnalysisDriverWithPackages._(
    this._sdkLibraryUris,
    this._packageLibraryUris,
    this._driver,
  );

  /// Current analysis session for getting errors, completion, etc.
  AnalysisSession get currentSession => _driver.currentSession;

  /// URIs of libraries in the SDK.
  List<Uri> get sdkLibraryUris => _sdkLibraryUris;

  /// URIs of libraries in the package bundle.
  List<String> get packageLibraryUris => _packageLibraryUris;

  /// Notify the driver that a file has changed.
  void changeFile(String path) => _driver.changeFile(path);

  /// Apply pending file changes.
  Future<void> applyPendingFileChanges() => _driver.applyPendingFileChanges();
}

/// A [UriResolver] that resolves `package:` URIs for packages present in a
/// [SummaryDataStore].
///
/// Unlike the standard [InSummaryUriResolver], which only resolves URIs
/// explicitly registered in [SummaryDataStore.uriToSummaryPath], this resolver
/// resolves ANY `package:X/...` URI as long as package `X` has at least one
/// library in the data store.
///
/// This is needed because a bundle's resolution bytes may reference internal
/// `package:X/src/...` URIs (from import/export directives) that weren't
/// individually registered. Without this resolver, deserialization in
/// `BundleReader._readDirectiveUri` fails with a null check error when it
/// calls `sourceFactory.forUri2(sourceUri)!`.
class PackageSummaryUriResolver extends UriResolver {
  final SummaryDataStore _dataStore;

  /// Known package names extracted from the data store's library URIs.
  late final Set<String> _knownPackages;

  PackageSummaryUriResolver(this._dataStore) {
    _knownPackages = <String>{};
    for (var uri in _dataStore.uriToSummaryPath.keys) {
      if (uri.startsWith('package:')) {
        var parsed = Uri.parse(uri);
        if (parsed.pathSegments.isNotEmpty) {
          _knownPackages.add(parsed.pathSegments.first);
        }
      }
    }
    // Also check library URIs directly
    for (var bundle in _dataStore.bundles) {
      for (var library in bundle.libraries) {
        var uriStr = library.uriStr;
        if (uriStr.startsWith('package:')) {
          var parsed = Uri.parse(uriStr);
          if (parsed.pathSegments.isNotEmpty) {
            _knownPackages.add(parsed.pathSegments.first);
          }
        }
      }
    }
  }

  @override
  Uri? pathToUri(String path) => null;

  @override
  Source? resolveAbsolute(Uri uri) {
    if (uri.scheme != 'package') return null;

    var uriString = uri.toString();

    // First, try exact match (same as InSummaryUriResolver)
    var summaryPath = _dataStore.uriToSummaryPath[uriString];
    if (summaryPath != null) {
      var isLibrary = _dataStore.hasLinkedLibrary(uriString);
      return InSummarySource(
        uri: uri,
        summaryPath: summaryPath,
        kind:
            isLibrary ? InSummarySourceKind.library : InSummarySourceKind.part,
      );
    }

    // Fallback: if the package is known, return a stub source.
    // This handles internal src/ files referenced in resolution bytes
    // that weren't individually registered in uriToSummaryPath.
    if (uri.pathSegments.isNotEmpty) {
      var packageName = uri.pathSegments.first;
      if (_knownPackages.contains(packageName)) {
        // Find any summary path associated with this package
        var fallbackPath = _findSummaryPathForPackage(packageName);
        return InSummarySource(
          uri: uri,
          summaryPath: fallbackPath ?? '',
          kind: InSummarySourceKind.library,
        );
      }
    }

    return null;
  }

  String? _findSummaryPathForPackage(String packageName) {
    var prefix = 'package:$packageName/';
    for (var entry in _dataStore.uriToSummaryPath.entries) {
      if (entry.key.startsWith(prefix)) {
        return entry.value;
      }
    }
    return null;
  }
}

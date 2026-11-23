@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_dart_analysis/tom_dart_analysis.dart';

/// The provider a driver is built over in these tests — the same shape the
/// production caller uses (`SummaryBackedDartAnalysisAdapter`), so what the
/// tests exercise is what ships: analysed source lives in an overlay above a
/// memory filesystem and never reaches a disk.
///
/// A fresh instance per driver, because a driver is per-editor and two editors
/// must not share an analysis buffer.
ResourceProvider analysisProvider() =>
    OverlayResourceProvider(MemoryResourceProvider());

/// Resolves the Dart SDK path inside the `flutter test` environment so we can
/// build a real SDK summary fixture once. Prefers `FLUTTER_ROOT` (set by the
/// flutter tool), falling back to the running executable's SDK.
String _resolveSdkPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final candidate = p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
    if (Directory(p.join(candidate, 'lib')).existsSync()) return candidate;
  }
  // .../dart-sdk/bin/dart → .../dart-sdk
  final sdk = p.dirname(p.dirname(Platform.resolvedExecutable));
  return sdk;
}

void main() {
  final registry = SummaryScopeRegistry.instance;

  // One real SDK summary, shared by every test (cheap to reuse, costly to
  // rebuild). Registration tests inject this via a counting loader, so they
  // never touch a real asset bundle.
  late Uint8List sdkSummaryBytes;

  setUpAll(() async {
    sdkSummaryBytes = await buildSdkSummary(
      resourceProvider: PhysicalResourceProvider.INSTANCE,
      sdkPath: _resolveSdkPath(),
    );
    expect(sdkSummaryBytes, isNotEmpty,
        reason: 'failed to build an SDK summary fixture');
  });

  // Per-test: a fresh registry and a loader that records every asset key it is
  // asked for, returning the shared SDK bytes for any key.
  late List<String> loadedKeys;
  setUp(() {
    registry.resetForTesting();
    loadedKeys = [];
    registry.bytesLoader = (key) async {
      loadedKeys.add(key);
      return sdkSummaryBytes;
    };
  });
  tearDown(() => registry.resetForTesting());

  const sdkOnly = SummaryScopeAsset(
    name: 'dart-plain',
    sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
    implicitImports: ['dart:async', 'dart:math'],
  );

  group('SummaryScopeRegistry.register', () {
    test('(a) is idempotent — re-registering reuses one scope, no reload',
        () async {
      final first = await registry.register(sdkOnly);
      final second = await registry.register(sdkOnly);

      expect(registry.isRegistered('dart-plain'), isTrue);
      expect(registry.length, 1, reason: 'only one entry for one name');
      expect(identical(first, second), isTrue,
          reason: 'same scope handle returned');
      // SDK loaded exactly once across both registrations (no package asset).
      expect(loadedKeys, ['assets/summaries/sdk_summary.sum']);
    });

    test('(b) two editors of one scope share a single parsed store', () async {
      await registry.register(sdkOnly);
      // Two independent lookups (as two editors would do).
      final scopeA = registry.scope('dart-plain')!;
      final scopeB = registry.scope('dart-plain')!;

      expect(identical(scopeA.model, scopeB.model), isTrue,
          reason: 'one shared ParsedSummaryModel');

      // Each editor builds its own cheap driver over the *same* model.
      final driverA = scopeA.createDriver(resourceProvider: analysisProvider());
      final driverB = scopeB.createDriver(resourceProvider: analysisProvider());
      expect(driverA.sdkLibraryUris, isNotEmpty);
      expect(driverB.sdkLibraryUris, isNotEmpty);
      expect(identical(driverA, driverB), isFalse,
          reason: 'drivers are per-editor, the store is shared');
    });

    test('(c) raw .sum bytes are loaded once and only the parsed model is kept',
        () async {
      final scope = await registry.register(sdkOnly);
      // Re-registering and building extra drivers must not reload bytes.
      await registry.register(sdkOnly);
      scope.createDriver(resourceProvider: analysisProvider());
      scope.createDriver(resourceProvider: analysisProvider());

      expect(loadedKeys.length, 1,
          reason: 'bytes fetched exactly once; no per-call byte copies held');
      // The scope exposes the parsed model, never the raw byte buffers — the
      // memory cost is one shared store regardless of editor count.
      expect(scope.model, isA<ParsedSummaryModel>());
      expect(scope.model.sdkLibraryUris, isNotEmpty);
    });

    test('loads the package asset too when present', () async {
      const withPackages = SummaryScopeAsset(
        name: 'with-pkgs',
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/with-pkgs/packages.sum',
      );
      // The fake loader returns SDK bytes for any key; a valid bundle parses,
      // so this exercises the two-asset load path without a real package bundle.
      await registry.register(withPackages);
      expect(loadedKeys, [
        'assets/summaries/sdk_summary.sum',
        'assets/summaries/with-pkgs/packages.sum',
      ]);
    });
  });

  group('SummaryScopeRegistry.scope', () {
    test('(d) an unknown scope resolves gracefully to null (unavailable)', () {
      expect(registry.scope('does-not-exist'), isNull);
      expect(registry.isRegistered('does-not-exist'), isFalse);
    });
  });

  group('SummaryScopeRegistry.release (ref-aware)', () {
    test('keeps the scope until the last reference is released', () async {
      await registry.register(sdkOnly); // refCount = 1
      await registry.register(sdkOnly); // refCount = 2

      registry.release('dart-plain'); // → 1
      expect(registry.isRegistered('dart-plain'), isTrue);

      registry.release('dart-plain'); // → 0, dropped
      expect(registry.isRegistered('dart-plain'), isFalse);
      expect(registry.scope('dart-plain'), isNull);
    });

    test('releasing an unknown scope is a no-op', () {
      expect(() => registry.release('nope'), returnsNormally);
    });
  });
}

@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_dart_editor/tom_dart_editor.dart';

/// Resolves the Dart SDK path inside the `flutter test` environment so we can
/// build a real SDK summary fixture once (mirrors the registry test helper).
String _resolveSdkPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final candidate = p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
    if (Directory(p.join(candidate, 'lib')).existsSync()) return candidate;
  }
  final sdk = p.dirname(p.dirname(Platform.resolvedExecutable));
  return sdk;
}

void main() {
  final registry = SummaryScopeRegistry.instance;

  // One real SDK summary, shared by every test. Adapter tests register an
  // sdk-only scope built from this and never touch a real asset bundle.
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

  group('SummaryBackedDartAnalysisAdapter.scope', () {
    test('two adapters of one scope share the registry parsed store', () async {
      await registry.register(sdkOnly);

      final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');
      final b = SummaryBackedDartAnalysisAdapter.scope('dart-plain');
      await a.ensureInitialized();
      await b.ensureInitialized();

      expect(a.debugResolvedScope, isNotNull);
      expect(b.debugResolvedScope, isNotNull);
      expect(identical(a.debugResolvedScope!.model, b.debugResolvedScope!.model),
          isTrue,
          reason: 'both adapters resolve to the one shared parsed model');

      // Bytes were loaded once (at register); resolving by name is a lookup, so
      // neither adapter reloads or re-parses the summary.
      expect(loadedKeys, ['assets/summaries/sdk_summary.sum']);
    });

    test('scope adapter inherits editor defaults (implicit imports) from scope',
        () async {
      await registry.register(sdkOnly);
      final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');
      await a.ensureInitialized();
      expect(a.implicitImports, ['dart:async', 'dart:math']);
    });

    test('per-instance overrides win over the scope defaults', () async {
      await registry.register(sdkOnly);
      final a = SummaryBackedDartAnalysisAdapter.scope(
        'dart-plain',
        implicitImports: const ['dart:collection'],
        includeAllPackageCompletions: true,
      );
      await a.ensureInitialized();
      expect(a.implicitImports, ['dart:collection']);
      expect(a.includeAllPackageCompletions, isTrue);
    });

    test('analyzes a snippet against the shared scope store', () async {
      await registry.register(sdkOnly);
      final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');
      final errors =
          await a.analyzeCode('void main() { final x = 1; print(x); }');
      // Clean snippet → no diagnostics surfaced; the key point is the analysis
      // ran against the shared store rather than throwing/loading its own bytes.
      expect(errors, isEmpty);
      expect(loadedKeys, ['assets/summaries/sdk_summary.sum']);
    });

    test('an unknown scope resolves gracefully to empty results', () async {
      final a = SummaryBackedDartAnalysisAdapter.scope('does-not-exist');
      await a.ensureInitialized();
      expect(a.debugResolvedScope, isNull);
      expect(await a.analyzeCode('void main() {}'), isEmpty);
      expect(await a.completions('void main() {}', 0, ''), isEmpty);
    });
  });

  group('SummaryBackedDartAnalysisAdapter (explicit-asset escape hatch)', () {
    test('default constructor keeps its documented implicit-import defaults',
        () {
      final a = SummaryBackedDartAnalysisAdapter();
      expect(a.scope, isNull);
      expect(a.implicitImports, [
        'dart:async',
        'dart:collection',
        'dart:math',
        'package:path/path.dart',
      ]);
      expect(a.includeAllPackageCompletions, isFalse);
    });
  });
}

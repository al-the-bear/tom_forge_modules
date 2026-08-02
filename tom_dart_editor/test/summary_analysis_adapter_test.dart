@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
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

  group('analysis keeps the analysed source in memory', () {
    test('surfaces real analyzer diagnostics for a deliberate error', () async {
      await registry.register(sdkOnly);
      final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');

      final errors =
          await a.analyzeCode("void main() { int x = 'not an int'; }");

      expect(errors, isNotEmpty,
          reason: 'a type error must still reach the caller');
      final invalidAssignment = errors.where(
        (e) => e.code.contains('invalid_assignment'),
      );
      expect(invalidAssignment, isNotEmpty,
          reason: 'diagnostics come from the analyzer, not a stub');
      // Offsets are rebased onto the user snippet, not the implicit-import
      // preamble, so line 1 is the snippet's first line.
      expect(invalidAssignment.first.line, 1);
    });

    test('analyses through an in-memory overlay, never a real file', () async {
      await registry.register(sdkOnly);
      final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');

      await a.analyzeCode("void main() { int x = 'not an int'; }");

      // The mechanism, asserted directly: the driver reads the snippet from an
      // overlay over an in-memory filesystem. There is no physical provider in
      // the chain, so there is no path by which the source could reach a disk.
      final provider = a.debugAnalysisResourceProvider;
      expect(provider.baseProvider, isA<MemoryResourceProvider>());
      expect(provider.hasOverlay(a.debugAnalysisPath), isTrue,
          reason: 'the analysed buffer lives in the overlay');
      expect(
        provider.getFile(a.debugAnalysisPath).readAsStringSync(),
        contains("int x = 'not an int';"),
      );
      // The base filesystem never received it — the overlay shadows a file
      // that was never created.
      expect(provider.baseProvider.getFile(a.debugAnalysisPath).exists, isFalse);
    });

    test('leaves no residue in the system temp directory', () async {
      await registry.register(sdkOnly);
      final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');
      // Warm the driver so the measured window covers only the analysis pass.
      await a.analyzeCode('void main() {}');

      final before =
          Directory.systemTemp.listSync().map((e) => e.path).toSet();

      await a.analyzeCode("void main() { int x = 'not an int'; }");

      final after =
          Directory.systemTemp.listSync().map((e) => e.path).toSet();

      // A weaker guard than it looks: the superseded temp-file path deleted its
      // directory in a `finally`, so a before/after diff could not see it, and
      // macOS delivers no watch events for the system temp directory. This
      // catches a *surviving* temp artifact (the lifetime hazard); the two
      // assertions above are what catch the write itself.
      expect(after.difference(before), isEmpty,
          reason: 'an analysis pass must leave nothing behind on disk');
      expect(after.where((p) => p.contains('dart_editor_analyzer_')), isEmpty,
          reason: 'the temp-directory analysis path must be gone entirely');
    });

    test('no library source reaches for a filesystem', () {
      // No allowlist. There was one — `summary_scope_registry.dart`, whose
      // `createDriver()` defaulted to PhysicalResourceProvider for callers that
      // passed none. wonecodeprp6 made the parameter required, which removed
      // both the import and the trap: a caller that forgets the provider now
      // fails to compile instead of silently analysing against a real disk.
      //
      // An empty allowlist is the point. Re-adding a name here is how this test
      // stops testing anything, so prefer injecting a provider at the call site.
      //
      // What this does NOT establish is web-compilability. It greps OUR sources
      // only, and `analyzer`'s own `physical_file_system.dart` — which imports
      // `dart:io` and is transitively reachable from this package's lib — is
      // outside its reach. The package's web build was measured directly (it
      // succeeds, both with and without the reference this test now forbids), so
      // the filesystem-reachability rule below is about analysed source staying
      // in memory, not about the platform. A real web-build check is wonecodeprpb7.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = p.relative(entity.path);
        final source = entity.readAsStringSync();
        if (source.contains("import 'dart:io'") ||
            source.contains('systemTemp') ||
            source.contains('physical_file_system.dart')) {
          offenders.add(relative);
        }
      }
      expect(offenders, isEmpty,
          reason: 'analysed source must never be able to reach a disk: no '
              'library source may name dart:io, systemTemp or a physical '
              'resource provider');
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

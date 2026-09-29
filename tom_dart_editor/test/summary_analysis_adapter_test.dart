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

    // What the analysis path used to create in the system temp, by name.
    const residueFamily = 'dart_editor_analyzer_';

    Set<String> residueIn(Directory directory) => directory
        .listSync()
        .map((e) => p.basename(e.path))
        .where((name) => name.startsWith(residueFamily))
        .toSet();

    /// An empty directory of this test's own, to stand in for the system temp.
    ///
    /// Under the workspace's `ztmp` when there is a workspace above, and under
    /// this package's `.dart_tool` when the repository is checked out alone.
    Directory privateTemp(String name) {
      Directory? workspace = Directory.current.absolute;
      while (workspace != null &&
          !Directory(p.join(workspace.path, '.tom_metadata')).existsSync()) {
        final parent = workspace.parent;
        workspace = parent.path == workspace.path ? null : parent;
      }
      final root = workspace == null
          ? p.join(Directory.current.path, '.dart_tool', 'test_tmp')
          : p.join(workspace.path, 'ztmp', 'tom_dart_editor_test');
      final directory = Directory(p.join(root, name));
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      directory.createSync(recursive: true);
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      return directory;
    }

    test('leaves no residue in the system temp directory', () async {
      // Two questions, each asked of a directory that can answer it.
      //
      // This used to diff the whole system temp before and after. That
      // directory is shared with every process on the machine — it held 68,661
      // entries when this was measured — so the assertion held only while
      // nothing else on the box created a file during two listings of it, and
      // it failed about one run in nine. A guard for a confidentiality rule
      // that fails for unrelated reasons is a guard somebody loosens.
      await registry.register(sdkOnly);

      // 1. By NAME, in the real system temp. Whatever else appears there is
      //    not ours to account for; an entry of the family the analysis path
      //    used to create is.
      final before = residueIn(Directory.systemTemp);

      // 2. By CATCH-ALL, in a directory nothing else writes to. Inside this
      //    zone `Directory.systemTemp` IS that directory, so anything the pass
      //    creates by asking Dart for the system temp lands where it can be
      //    seen — whatever it is called.
      final private = privateTemp('no_residue');
      await IOOverrides.runZoned(
        () async {
          final a = SummaryBackedDartAnalysisAdapter.scope('dart-plain');
          await a.analyzeCode('void main() {}');
          await a.analyzeCode("void main() { int x = 'not an int'; }");
        },
        getSystemTempDirectory: () => private,
      );

      // A weaker guard than it looks: the superseded temp-file path deleted its
      // directory in a `finally`, so a before/after listing could not see it.
      // This catches a *surviving* temp artifact (the lifetime hazard); the
      // test above is what catches the write itself.
      expect(private.listSync(), isEmpty,
          reason: 'an analysis pass must leave nothing behind on disk');
      expect(residueIn(Directory.systemTemp).difference(before), isEmpty,
          reason: 'the temp-directory analysis path must be gone entirely');
    });

    test('the no-residue guard can see what it guards against', () async {
      // The control. A redirected system temp that the code under test never
      // consulted, or a family filter that matched nothing, would leave the
      // test above green while watching an empty room.
      final private = privateTemp('no_residue_control');
      final before = residueIn(private);

      await IOOverrides.runZoned(
        () async {
          // The superseded path, as it was: a directory of the family, made by
          // asking for the system temp — after an await, because the analysis
          // pass does its work asynchronously and the override has to follow.
          await Future<void>.delayed(Duration.zero);
          final made = await Directory.systemTemp.createTemp(residueFamily);
          File(p.join(made.path, 'snippet.dart')).writeAsStringSync('x');
        },
        getSystemTempDirectory: () => private,
      );

      expect(private.listSync(), hasLength(1),
          reason: 'the catch-all sees a surviving artifact');
      expect(residueIn(private).difference(before), hasLength(1),
          reason: 'and the family filter names it');
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
      // What this does NOT establish is web-compilability — and the reason is
      // stronger than "it only greps our own sources". Naming `dart:io` simply
      // does not decide a Flutter web build. The import closure of this
      // package's public entry point is ~1900 libraries, 45 of which name
      // `dart:io` unconditionally, headed by `package:flutter/services.dart` →
      // `src/services/text_input.dart` (`import 'dart:io' show Platform;`) —
      // present in every Flutter web app ever built. So this grep is not an
      // incomplete web check; it is a different check. The rule below is about
      // analysed source staying in memory (D-D33-9), which is confidentiality.
      // The web build is measured for real in `web_build_test.dart`.
      final offenders = <String>[];
      var scanned = 0;
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final relative = p.relative(entity.path);
        scanned++;
        final source = entity.readAsStringSync();
        if (source.contains("import 'dart:io'") ||
            source.contains('systemTemp') ||
            source.contains('physical_file_system.dart')) {
          offenders.add(relative);
        }
      }
      // Anti-vacuity: an empty `offenders` also results from scanning nothing —
      // a moved `lib/`, a renamed extension, a wrong working directory. The
      // floor is deliberately well below the real count so it tracks a broken
      // scan, not the package's size.
      expect(scanned, greaterThanOrEqualTo(8),
          reason: 'only $scanned library sources were scanned — the scan is '
              'broken, so an empty offender list means nothing');
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

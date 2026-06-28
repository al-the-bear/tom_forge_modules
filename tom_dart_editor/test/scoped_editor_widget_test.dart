@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/sdk/build_sdk_summary.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_dart_editor/tom_dart_editor.dart';

/// Resolves the Dart SDK path inside the `flutter test` environment (mirrors the
/// registry/adapter test helpers).
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

  late Uint8List sdkSummaryBytes;
  setUpAll(() async {
    sdkSummaryBytes = await buildSdkSummary(
      resourceProvider: PhysicalResourceProvider.INSTANCE,
      sdkPath: _resolveSdkPath(),
    );
    expect(sdkSummaryBytes, isNotEmpty);
  });

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

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 1600, height: 600, child: child),
        ),
      );

  testWidgets('editor instantiated by scope: analyzes against the shared registry',
      (tester) async {
    await registry.register(sdkOnly);

    final controller =
        DartCodeController(initialCode: 'void main() { final x = 1; print(x); }');
    addTearDown(controller.dispose);

    final errorRounds = <List<CodeError>>[];

    await tester.runAsync(() async {
      await tester.pumpWidget(
        host(
          SummaryBackedDartCodeEditor(
            controller: controller,
            scope: 'dart-plain',
            settings: const DartEditorSettings(showToolbar: false),
            onErrorsChanged: errorRounds.add,
          ),
        ),
      );

      // initState schedules an immediate analysis; let the real analyzer finish.
      for (var i = 0; i < 60 && errorRounds.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(errorRounds, isNotEmpty,
        reason: 'the scoped adapter ran an analysis pass');
    expect(errorRounds.last, isEmpty,
        reason: 'a clean snippet produces no diagnostics');
    // Bytes were loaded once (at register); the editor reused the shared store.
    expect(loadedKeys, ['assets/summaries/sdk_summary.sum']);
  });

  testWidgets('an absent scope degrades to empty diagnostics (no crash)',
      (tester) async {
    // No registration: the named scope is unavailable.
    final controller = DartCodeController(initialCode: 'void main() {}');
    addTearDown(controller.dispose);

    final errorRounds = <List<CodeError>>[];

    await tester.runAsync(() async {
      await tester.pumpWidget(
        host(
          SimpleSummaryBackedDartCodeEditor(
            initialCode: 'void main() {}',
            scope: 'does-not-exist',
            settings: const DartEditorSettings(showToolbar: false),
            onErrorsChanged: errorRounds.add,
          ),
        ),
      );

      for (var i = 0; i < 20 && errorRounds.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    expect(errorRounds, isNotEmpty, reason: 'analysis pass still completed');
    expect(errorRounds.last, isEmpty,
        reason: 'unavailable scope → no diagnostics, no throw');
    expect(loadedKeys, isEmpty, reason: 'nothing registered, nothing loaded');
  });
}

/// The summary scopes the bundler builds from `buildkit.yaml`
/// (`assets/summaries/**`, registered by the generated
/// `summary_scopes.g.dart`) analyse what their code fields hold: Flutter
/// code in the d4rt-flutter scope — its widgets and the `dart:ui` types
/// Flutter re-exports — and plain Dart in the dart-plain scope.
///
/// The bundles are generated, not committed: on a checkout that has not run
/// the bundler (`dart run ../tom_dart_editor_bundler/bin/dart_editor_bundler.dart
/// --config buildkit.yaml`) the tests are skipped, saying so.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_specs_editor/generated/summary_scopes.g.dart';

const _sdk = 'assets/summaries/sdk_summary.sum';
const _flutter = 'assets/summaries/d4rt-flutter/packages.sum';

void main() {
  final missing = [
    for (final asset in [_sdk, _flutter])
      if (!File(asset).existsSync()) asset,
  ];
  final skip = missing.isEmpty
      ? false
      : 'generated summaries missing (${missing.join(', ')}): run the bundler';

  final registry = SummaryScopeRegistry.instance;
  setUp(() {
    registry.resetForTesting();
    registry.bytesLoader = (key) async =>
        Uint8List.fromList(await File(key).readAsBytes());
  });
  tearDown(registry.resetForTesting);

  Future<List<String>> errorsIn(String scope, String code) async {
    await SummaryScopes.initialize();
    final adapter = SummaryBackedDartAnalysisAdapter.scope(scope);
    await adapter.ensureInitialized();
    return [
      for (final e in await adapter.analyzeCode(code))
        if (e.severity == 'error') '${e.code}: ${e.message}',
    ];
  }

  test('SCOPE-1: d4rt-flutter resolves Flutter widgets and the dart:ui types '
      'Flutter re-exports (TextDirection, Color, Offset)', () async {
    final errors = await errorsIn(SummaryScopes.d4rtFlutter, '''
import 'package:flutter/material.dart';

Widget label() => const Text('x', textDirection: TextDirection.ltr);

const Color red = Color(0xFFFF0000);
const Offset origin = Offset.zero;
''');
    expect(errors, isEmpty, reason: errors.join('\n'));

    final broken = await errorsIn(SummaryScopes.d4rtFlutter, '''
import 'package:flutter/material.dart';

const direction = TextDirection.sideways;
''');
    expect(broken, isNotEmpty, reason: 'a mistake is still reported');
  }, skip: skip);

  test('SCOPE-2: dart-plain analyses plain Dart against the shared SDK '
      'summary', () async {
    final errors = await errorsIn(SummaryScopes.dartPlain, '''
import 'dart:async';
import 'dart:math';

Future<int> roll() async => Random().nextInt(6);
''');
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, skip: skip);
}

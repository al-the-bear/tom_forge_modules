/// The summary pair the apps ship (`assets/sdk_summary.sum`,
/// `assets/packages.sum`) is readable by the analyzer the editor runs on and
/// resolves real code — the SDK, a package and Flutter — and every app ships
/// the same pair (`tom_dart_editor/doc/package_summary_generation.md`, "When
/// to rebuild"). A pair written by another analyzer major fails here.
/// Flutter's `dart:ui` types are not covered yet (tom_forge
/// later14_akga-dart-ui-in-editor-summaries).
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

const _sdk = 'assets/sdk_summary.sum';
const _packages = 'assets/packages.sum';

void main() {
  final registry = SummaryScopeRegistry.instance;

  setUp(() {
    registry.resetForTesting();
    registry.bytesLoader = (key) async =>
        Uint8List.fromList(await File(key).readAsBytes());
  });
  tearDown(registry.resetForTesting);

  test('SUM-1: code using the SDK, a package and Flutter analyses clean '
      'against the shipped summaries; a mistake is reported', () async {
    await registry.register(
      const SummaryScopeAsset(
        name: 'shipped',
        sdkSummaryAsset: _sdk,
        packageSummaryAsset: _packages,
      ),
    );
    final adapter = SummaryBackedDartAnalysisAdapter.scope('shipped');
    await adapter.ensureInitialized();

    const clean = '''
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:flutter/widgets.dart';

Future<String> joined() async => p.join('a', 'b');

Widget box() => const SizedBox(width: 1, height: 2);
''';
    final errors = await adapter.analyzeCode(clean);
    expect(
      errors.where((e) => e.severity == 'error'),
      isEmpty,
      reason: errors.map((e) => '${e.code}: ${e.message}').join('\n'),
    );

    final broken = await adapter.analyzeCode('''
import 'package:path/path.dart' as p;
String joined() => p.joinn('a', 'b');
''');
    expect(
      broken.where((e) => e.severity == 'error'),
      isNotEmpty,
      reason: 'an undefined function is an error',
    );
  });

  test('SUM-2: every app ships the same pair', () {
    for (final app in ['../tom_forge_app', '../tom_yaml_editor_test']) {
      for (final file in [_sdk, _packages]) {
        expect(
          File('$app/$file').readAsBytesSync(),
          File(file).readAsBytesSync(),
          reason: '$app/$file differs from this package\'s: copy the pair',
        );
      }
    }
  });
}

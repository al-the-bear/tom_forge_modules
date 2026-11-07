/// The summary pair the apps ship (`assets/sdk_summary.sum`,
/// `assets/packages.sum`) is readable by the analyzer the editor runs on and
/// resolves real code — the SDK, a package, Flutter and the `dart:ui` types
/// Flutter re-exports — and every app ships the same pair
/// (`tom_dart_editor/doc/package_summary_generation.md`, "When to rebuild").
/// A pair written by another analyzer major fails here.
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

  test('SUM-1: code using the SDK, a package, Flutter and dart:ui analyses '
      'clean against the shipped summaries, and so does plain Dart code; a '
      'mistake is reported', () async {
    await registry.register(
      const SummaryScopeAsset(
        name: 'shipped',
        sdkSummaryAsset: _sdk,
        packageSummaryAsset: _packages,
      ),
    );
    final adapter = SummaryBackedDartAnalysisAdapter.scope('shipped');
    await adapter.ensureInitialized();

    Future<void> expectClean(String code) async {
      final errors = await adapter.analyzeCode(code);
      expect(
        errors.where((e) => e.severity == 'error'),
        isEmpty,
        reason: errors.map((e) => '${e.code}: ${e.message}').join('\n'),
      );
    }

    // Flutter: its widgets, and the dart:ui types it re-exports.
    await expectClean('''
import 'dart:async';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:flutter/widgets.dart';

Future<String> joined() async => p.join('a', 'b');

Widget box() => const SizedBox(width: 1, height: 2);

Widget label() => const Text('x', textDirection: TextDirection.ltr);

const Color red = Color(0xFFFF0000);
const Offset origin = Offset.zero;
final ui.Size size = const ui.Size(1, 2);
''');

    // Plain Dart: the SDK the summary also holds.
    await expectClean('''
import 'dart:convert';
import 'dart:io';

Future<String> read(String path) => File(path).readAsString();

String encoded(Map<String, Object?> data) => jsonEncode(data);

void main() => stdout.writeln(Platform.operatingSystem);
''');

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

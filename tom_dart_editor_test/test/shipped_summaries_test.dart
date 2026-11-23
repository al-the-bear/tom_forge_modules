/// The summary pair the apps ship — built by tom_dart_editor_bundler from
/// this package's buildkit.yaml: `assets/summaries/sdk_summary.sum` and
/// `assets/summaries/dart-editor/packages.sum`, each with its stamp — is
/// readable by the analyzer the editor runs on and resolves real code (the
/// SDK, a package, Flutter and the `dart:ui` types Flutter re-exports), and
/// every app ships the same pair
/// (`tom_dart_analysis/doc/package_summary_generation.md`). A pair written by
/// another analyzer fails here.
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_analysis/tom_dart_analysis.dart';
import 'package:tom_dart_editor_test/generated/summary_scopes.g.dart';

const _sdk = 'assets/summaries/sdk_summary.sum';
const _packages = 'assets/summaries/dart-editor/packages.sum';

/// Every file of the pair the bundler writes: the two summaries and their
/// stamps.
const _pair = [_sdk, '$_sdk.stamp', _packages, '$_packages.stamp'];

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
    // Registered as the app does, through the bundler's generated helper.
    await SummaryScopes.initialize();
    final adapter = SummaryBackedDartAnalysisAdapter.scope(
      SummaryScopes.dartEditor,
    );
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

  test('SUM-2: every app ships the same pair, stamps included', () {
    for (final app in ['../tom_forge_app', '../tom_yaml_editor_test']) {
      for (final file in _pair) {
        expect(
          File('$app/$file').readAsBytesSync(),
          File(file).readAsBytesSync(),
          reason: '$app/$file differs from this package\'s: copy the pair',
        );
      }
    }
  });

  test('SUM-3: each summary carries the bundler\'s stamp, built with dart:ui',
      () {
    for (final summary in [_sdk, _packages]) {
      final stamp = File('$summary.stamp');
      expect(stamp.existsSync(), isTrue, reason: '$summary has no stamp');
      expect(stamp.readAsStringSync(), contains('dart-ui: yes'));
      expect(
        stamp.readAsStringSync(),
        matches(RegExp(r'toolchain: \d+\.\d+\.\d+\+d\d+')),
      );
    }
  });
}

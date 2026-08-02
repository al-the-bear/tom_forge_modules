// Does this package compile for the web?
//
// D3 §5 lists Web as a supported Webwork platform and says feature degradation
// is limited to its backend table — "no other behavior forks per platform". D33
// §3.6 turns that into an obligation on this package: "Every D3 target MUST be
// verified to build with it before §3 is considered done; targets where it does
// not build fall back to §3.7." §3.7 is therefore the answer to a *measured*
// failure, not a standing exemption — which makes the measurement load-bearing.
//
// WHY A REAL BUILD AND NOT A GREP. The obvious cheap instrument is to scan the
// import graph for `dart:io`. It does not work, and not merely because it would
// miss transitive dependencies. It measures the wrong property. Walking the
// import/export closure of `package:tom_dart_editor/tom_dart_editor.dart` finds
// ~1900 libraries, of which 45 name `dart:io` unconditionally — and the list is
// led by Flutter itself: `package:flutter/services.dart` exports
// `src/services/text_input.dart`, whose second line is
// `import 'dart:io' show Platform;`. That library is in the closure of every
// Flutter web app ever built. So "a reachable library names dart:io" does not
// predict a failing web build in either direction, and no amount of tidying our
// own imports establishes web support. Only the build decides.
//
// `test/summary_analysis_adapter_test.dart` has a grep that looks like this
// check but is not: it enforces that *analysed source* stays in memory, which
// is a confidentiality rule (D33 §3.6, D-D33-9). It says so itself.
//
// COST AND GATING. The build takes roughly a minute, against ~15s for the rest
// of the suite, so it is tempting to hide it behind an opt-in env var. It runs
// by default anyway: this repository has no CI (the only workflow directory in
// the workspace is `.github/workflows_retired/`, and `tom_forge` has none), and
// an opt-in check in a repository with no CI is a check that never runs — which
// is the exact absence this test exists to close. Set `TOM_SKIP_WEB_BUILD=1` to
// opt out during a tight inner loop.
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('web compilability', () {
    // The vehicle is the companion app rather than a bespoke probe: it is the
    // package's existing `*_test` app (the tom_forge convention), it drives the
    // real `SimpleSummaryBackedDartCodeEditor` over asset-loaded summaries —
    // which is precisely the in-memory path D33 §3.6 requires of a web build —
    // and it is one app to keep working rather than two.
    //
    // Its `dcli` dependency is not an obstacle, though it looks like one. `dcli`
    // is a fixture *source* for `tool/build_packages_summary.dart`, which bundles
    // its libraries into `assets/packages.sum`; nothing under `lib/` imports it.
    // A declared dependency that the entry point never reaches is never
    // compiled, so it cannot fail a web build.
    final appDir = Directory(p.join('..', 'tom_dart_editor_test'));
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final flutter = flutterRoot == null
        ? null
        : p.join(flutterRoot, 'bin', Platform.isWindows ? 'flutter.bat' : 'flutter');

    String? skipReason() {
      if (Platform.environment['TOM_SKIP_WEB_BUILD'] == '1') {
        return 'TOM_SKIP_WEB_BUILD=1 is set; unset it to measure the web build';
      }
      if (!appDir.existsSync()) {
        return 'the companion app is missing at ${appDir.path} — this test '
            'builds it, so it cannot run without it';
      }
      if (!Directory(p.join(appDir.path, 'web')).existsSync()) {
        return 'the companion app has no web/ scaffold — run '
            '`flutter create --platforms=web .` in ${appDir.path}';
      }
      if (!File(p.join(appDir.path, '.dart_tool', 'package_config.json'))
          .existsSync()) {
        return 'the companion app has no resolved packages — run '
            '`flutter pub get` in ${appDir.path} (this test does not resolve '
            'dependencies, so that an offline run fails loudly rather than '
            'hanging on the network)';
      }
      if (flutter == null || !File(flutter).existsSync()) {
        return 'FLUTTER_ROOT does not point at a flutter executable '
            '(${flutterRoot ?? 'unset'})';
      }
      return null;
    }

    final skip = skipReason();

    test('the companion app compiles for the web with dart2js', () async {
      final result = await Process.run(
        flutter!,
        const ['build', 'web'],
        workingDirectory: appDir.absolute.path,
      );

      // The full output on failure, not a summary: a web-build failure names one
      // library in one package, and that name is the entire diagnostic value.
      expect(
        result.exitCode,
        0,
        reason: 'flutter build web failed for tom_dart_editor_test, so '
            'tom_dart_editor does not satisfy the D33 §3.6 obligation for the '
            'D3 §5 web target. Either fix the offending import or move the web '
            'target to the D33 §3.7 degraded editor — do not delete this test.\n'
            'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );

      // Anti-vacuity: a zero exit code from a command that silently did nothing
      // would pass the assertion above. The compiled entry point must exist.
      final output = File(p.join(appDir.path, 'build', 'web', 'main.dart.js'));
      expect(
        output.existsSync(),
        isTrue,
        reason: 'flutter build web reported success but produced no '
            'main.dart.js — the build did not actually compile anything',
      );
    }, skip: skip);
  });
}

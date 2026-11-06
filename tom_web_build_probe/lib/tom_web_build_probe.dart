/// One `flutter build web`, declared once and used by every Forge editor that
/// claims the web target.
///
/// D3 §5 lists Web as a supported Webwork platform and D33 §3.6 turns that into
/// an obligation on the editor packages: "Every D3 target MUST be verified to
/// build with it before §3 is considered done." `tom_dart_editor` proved its own
/// first; this exists because the second one would otherwise have been a copy
/// of the first, and the fourth a copy of a copy.
///
/// **Why a real build and not a grep.** The obvious cheap instrument is to scan
/// the import graph for `dart:io`. It measures the wrong property: `dart:io` is
/// a declared dart2js library, so ~45 libraries in a typical editor's closure
/// name it — Flutter's own `services.dart` among them — and every Flutter web
/// app ever built contains them. What actually fails a web build is a library
/// dart2js has no implementation for at all (`dart:ffi`), or a type that two
/// packages resolve differently across the `dart.library.js_interop` boundary.
/// Neither is visible to a grep. See `tom_dart_editor/README.md`, "Why
/// `dart:io` compiles for the web and `dart:ffi` does not".
///
/// **Why it is a dev_dependency package and not a helper inside
/// `tom_editors_shared`.** A test can only import a dependency's `lib/`, and
/// putting `dart:io` + `Process` into the editors' shared *library* to reach it
/// from tests would put build machinery in the closure of every editor — the
/// closure this very probe measures. It is also the only arrangement that
/// serves `tom_flow_editor`, which does not depend on `tom_editors_shared` at
/// all.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Registers the web-build test for the companion app at [appDirectory],
/// relative to the package under test.
///
/// [id] is the test id prefix, so a failure names which editor it came from
/// without the reader opening the file.
///
/// The test is **default-on**. It is tempting to gate a minute-long build
/// behind an opt-in variable, and that was considered and rejected for
/// `tom_dart_editor`: this repository has no CI, and an opt-in check in a
/// repository with no CI is a check that never runs — which is the exact
/// absence it exists to close. `TOM_SKIP_WEB_BUILD=1` opts out for a tight
/// inner loop.
void registerWebBuildTest({
  required String id,
  required String appDirectory,
  String? because,
}) {
  final appDir = Directory(appDirectory);
  final flutter = _flutterExecutable(Platform.environment);
  final skip = webBuildSkipReason(
    appDirectory: appDirectory,
    environment: Platform.environment,
  );

  test('$id: the companion app compiles for the web with dart2js', () async {
    final result = await Process.run(
      flutter!,
      const ['build', 'web'],
      workingDirectory: appDir.absolute.path,
    );

    // The full output on failure, not a summary: a web-build failure names one
    // library and the exact import chain that reached it, and that chain is
    // the entire diagnostic value.
    expect(
      result.exitCode,
      0,
      reason: 'flutter build web failed for ${p.basename(appDir.path)}, so '
          'this package does not satisfy the D33 §3.6 obligation for the D3 §5 '
          'web target. The compiler names the import chain below — take it to '
          '§3.6 as a platform-matrix fact if it is a real impossibility, and '
          'fix it if it is ours. Do not delete this test.'
          '${because == null ? '' : '\n$because'}\n'
          'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );

    // Anti-vacuity: a zero exit code from a command that silently did nothing
    // would pass the assertion above. The compiled entry point must exist.
    expect(
      File(p.join(appDir.path, 'build', 'web', 'main.dart.js')).existsSync(),
      isTrue,
      reason: 'flutter build web reported success but produced no '
          'main.dart.js — the build did not actually compile anything',
    );
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}

/// The flutter executable under `FLUTTER_ROOT` in [environment], or null when
/// it is unset.
String? _flutterExecutable(Map<String, String> environment) {
  final flutterRoot = environment['FLUTTER_ROOT'];
  return flutterRoot == null
      ? null
      : p.join(
          flutterRoot, 'bin', Platform.isWindows ? 'flutter.bat' : 'flutter');
}

/// Why the web-build test for the companion app at [appDirectory] cannot run
/// in [environment], or null when it runs. Every reason names what would
/// make it run: a skip reason that says only "unavailable" is a test nobody
/// ever turns back on.
String? webBuildSkipReason({
  required String appDirectory,
  required Map<String, String> environment,
}) {
  final appDir = Directory(appDirectory);
  final flutter = _flutterExecutable(environment);
  if (environment['TOM_SKIP_WEB_BUILD'] == '1') {
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
        '(${environment['FLUTTER_ROOT'] ?? 'unset'})';
  }
  return null;
}

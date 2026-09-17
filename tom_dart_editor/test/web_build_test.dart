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
import 'package:tom_web_build_probe/tom_web_build_probe.dart';

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
    // The build itself is the shared probe now. It was the only one when it
    // was written; `wonecodeprpc18` gave three more editors the same check, and
    // a second copy of a minute-long build with its own skip reasons is how the
    // reasons drift apart.
    registerWebBuildTest(
      id: 'WONECODEPRPC18-dart_editor',
      appDirectory: '../tom_dart_editor_test',
      because: 'This package is the one that carries the summary-backed '
          'AnalysisDriver, so its web build is the D33 §3.6 case that matters '
          'most.',
    );

    // ── Why the build above is allowed to pass ───────────────────────────
    //
    // `wonecodeprpb7` found that `import 'dart:ffi'` is refused by dart2js
    // while `dart:io` — named unconditionally by 45 libraries in this
    // package's closure, Flutter's own `services.dart` among them — compiles
    // without a murmur, and could not say why. The answer is in the SDK's
    // manifest rather than in the compiler:
    //
    //   `dart-sdk/lib/libraries.json`'s `dart2js` target holds only eight
    //   libraries of its own, which is what makes `io` look absent. It is
    //   defined as `"include": [{"target": "_dart2js_common"}]`, and
    //   `_dart2js_common` declares `io` with
    //   `patches: _internal/js_runtime/lib/io_patch.dart` and
    //   `support_conditional_import: false`. `dart:ffi` is in no dart2js
    //   target at all. `flutter_web_sdk` includes the same dart-sdk target.
    //
    // So it is **not** tree-shaking: the symbols are genuinely available, and
    // the ~825-line patch is stubs that throw at run time. Compilable and
    // usable are different properties.
    //
    // These pin the two halves that a toolchain change could reverse. They cost
    // about two seconds against the build's minute, and they fail with the
    // reason attached rather than leaving the real build to fail somewhere
    // unhelpful. They do not need Flutter — `dart compile js` IS dart2js, and
    // the `io` entry it reads is the one `flutter_web_sdk` inherits.
    group('the dart:io / dart:ffi asymmetry, which is the SDK manifest', () {
      // Scratch space under the workspace `ztmp`, never `/tmp`, and located by
      // landmark rather than by counting `..` — the count would be right only
      // at the depth it was written at.
      Directory? workspaceRoot() {
        var dir = Directory.current.absolute;
        while (true) {
          if (Directory(p.join(dir.path, '.tom_metadata')).existsSync()) {
            return dir;
          }
          final parent = dir.parent;
          if (parent.path == dir.path) return null;
          dir = parent;
        }
      }

      final root = workspaceRoot();
      // The c17 probes need the dart-sdk binary, which the build test no longer
      // resolves here — it moved into the shared probe with the build.
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      final dart = flutterRoot == null
          ? null
          : p.join(flutterRoot, 'bin', 'cache', 'dart-sdk', 'bin',
              Platform.isWindows ? 'dart.exe' : 'dart');
      final probeSkip = root == null
          ? 'no workspace root above ${Directory.current.path}, so there is no '
              'ztmp to compile a probe in'
          : (dart == null || !File(dart).existsSync())
              ? 'FLUTTER_ROOT does not point at a dart executable'
              : null;

      late Directory scratch;
      setUp(() {
        scratch = Directory(p.join(root!.path, 'ztmp', 'dart_editor_web_probe'))
          ..createSync(recursive: true);
      });
      tearDown(() {
        if (scratch.existsSync()) scratch.deleteSync(recursive: true);
      });

      Future<ProcessResult> compileJs(String name, String source) async {
        final file = File(p.join(scratch.path, '$name.dart'))
          ..writeAsStringSync(source);
        return Process.run(dart!, [
          'compile',
          'js',
          '-o',
          p.join(scratch.path, '$name.js'),
          file.path,
        ]);
      }

      test('dart:io is USED, not merely imported, and still compiles', () async {
        // Using the library is the whole point of the case. An unused import
        // would compile even if the allowance were nothing but tree-shaking,
        // which is the explanation this rules out.
        final result = await compileJs('io_used', '''
import 'dart:io';
void main() {
  print(File('nope.txt').existsSync());
  print(Directory.current.path);
  print(Platform.operatingSystem);
}
''');

        expect(
          result.exitCode,
          0,
          reason: 'dart2js refused a dart:io-using program. That reverses a '
              'documented SDK allowance (_dart2js_common declares io, patched '
              'by _internal/js_runtime/lib/io_patch.dart), so the web build '
              'above is about to fail for every library in the closure that '
              'names dart:io — 45 of them, Flutter services.dart included.\n'
              '${result.stdout}\n${result.stderr}',
        );
      }, skip: probeSkip);

      test('dart:ffi is still refused, which is what a real absence looks like',
          () async {
        final result = await compileJs('ffi_used', '''
import 'dart:ffi';
void main() => print(sizeOf<Int8>());
''');

        // The contrast is the evidence. Both libraries are "not on the web" in
        // casual speech; only one of them is absent from the dart2js manifest,
        // and this is what that difference looks like from outside.
        expect(result.exitCode, isNot(0),
            reason: 'dart:ffi compiled for dart2js, so the asymmetry this '
                'group documents no longer holds and the README section '
                '"Why dart:io compiles for the web" is out of date');
        expect(
          '${result.stdout}${result.stderr}',
          contains("Dart library 'dart:ffi' is not available on this platform"),
          reason: 'it failed for some other reason, which means this test has '
              'stopped measuring what it claims to',
        );
      }, skip: probeSkip);

      test('dart.library.io is false even though dart:io is available',
          () async {
        // `support_conditional_import: false`. Availability and the
        // environment flag are different questions, and a conditional import
        // must keep routing away from dart:io on the web — which is what makes
        // the allowance safe rather than a trap.
        final result = await compileJs('env', '''
void main() {
  print('io=\${const bool.fromEnvironment('dart.library.io')}');
}
''');
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');

        final node = await Process.run('node', [p.join(scratch.path, 'env.js')]);
        expect(node.exitCode, 0,
            reason: 'could not run the compiled probe: ${node.stderr}');
        expect(
          node.stdout.toString().trim(),
          'io=false',
          reason: 'dart.library.io became true for dart2js. Conditional '
              'imports across the workspace route on this flag, so they would '
              'now select dart:io branches in web builds',
        );
      }, skip: probeSkip);
    });
  });
}

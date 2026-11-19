// Tolerant golden comparator — absorbs sub-pixel font / anti-aliasing drift
// that differs across hosts and Flutter engine revisions, so pixel goldens do
// not oscillate red when the same suite runs on a different machine.
//
// Why: Flutter's default `LocalFileComparator` is exact-match. The shell
// screenshots render themed text and icons; font hinting and anti-aliasing
// produce tiny per-pixel differences between the host/engine that generated the
// goldens and any other host/engine — the same font/AA drift that RCJ16 saw on
// the sibling Flutter suites after the Flutter 3.44.6 SDK bump. A percentage
// threshold lets that sub-pixel noise pass while genuine visual regressions
// (layout shifts, colour/theme changes) still fail, because those move far more
// than the threshold's worth of pixels.
//
// `flutter test` auto-discovers this file (walking up from the test file to the
// package root) and runs `testExecutable` before the suite, installing the
// comparator. See quest todo RCJ17.
//
// It also registers Forge's desktop components (the terminal, the code
// editors, the keychain) for every shell the suites make, as an application
// does at start (useForgeDesktopComponents).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart' show useForgeDesktopComponents;

/// Fraction (0.0–1.0) of pixel difference tolerated before a golden fails.
/// 3% comfortably absorbs the observed <1.5% cross-host font/AA drift with
/// margin, while staying well below the double-digit deltas a real layout or
/// theme regression produces.
const double _goldenTolerance = 0.03;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  useForgeDesktopComponents();
  final defaultComparator = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantGoldenComparator(
    // Append a filename so LocalFileComparator's internal dirname() recovers the
    // exact original basedir (the running test file's directory).
    Uri.parse('${defaultComparator.basedir}flutter_test_config.dart'),
    tolerance: _goldenTolerance,
  );
  await testMain();
}

/// [LocalFileComparator] that passes when the pixel difference is within
/// [tolerance]; otherwise it fails exactly like the default comparator
/// (writing the failure PNGs and throwing).
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

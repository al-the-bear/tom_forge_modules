import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> prepareLargeSurface(
  WidgetTester tester, {
  Size size = const Size(2200, 2400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> sendPrimaryShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  final usesMeta = defaultTargetPlatform == TargetPlatform.macOS;
  final primary = usesMeta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;

  await tester.sendKeyDownEvent(primary);
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyUpEvent(primary);
}

void suppressOverflowErrorsForTest() {
  final oldOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = oldOnError);
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
}

// Smoke test: the TomSpecs Editor launches a blank Forge shell (step 8).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'package:tom_specs_editor/src/specs_editor_app.dart';

void main() {
  testWidgets('SpecsEditorApp launches a blank Forge shell', (tester) async {
    // The Forge shell is a desktop IDE layout; give it a realistic window so
    // its toolbar/panels lay out without a (cosmetic) overflow at the tiny
    // 800x600 default test surface.
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SpecsEditorApp());
    await tester.pump();

    // The standard Forge shell scaffold is mounted — the app is a Forge shell,
    // not a bare MaterialApp.
    expect(find.byType(ForgeShellScaffold), findsOneWidget);
    // No FlutterError was thrown while building the empty layout.
    expect(tester.takeException(), isNull);
  });
}

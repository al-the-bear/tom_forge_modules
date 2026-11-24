/// The Problems view's toolbar fits every width the bottom panel can take:
/// the filter chips, the info count and the search bar never overflow. Seen
/// in tom_forge_app at start-up, where the bottom panel was narrower than the
/// chips and the count (`A RenderFlex overflowed by 6.6 pixels`). Overflow
/// errors are NOT suppressed here: one fails the test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_problems_view/tom_forge_problems_view.dart';

ForgeTextRange _range(int line) => ForgeTextRange(
  start: ForgeTextPosition(line: line, column: 0),
  end: ForgeTextPosition(line: line, column: 1),
);

void main() {
  testWidgets(
    'PROBLEMS-NARROW-1: the toolbar and the rows fit from 120 px to 800 px, '
    'with three-digit counts',
    (tester) async {
      final diagnostics = DefaultDiagnosticManager();
      final uri = Uri.file('/a.dart');
      diagnostics.createCollection('narrow').set(uri, [
        for (var i = 0; i < 345; i++)
          ForgeDiagnostic(
            uri: uri,
            range: _range(i),
            message: 'Problem $i',
            severity: ForgeSeverity.values[i % ForgeSeverity.values.length],
            source: 'analyzer',
          ),
      ]);
      final view = ForgeProblemsView(
        diagnosticManager: diagnostics,
        openFile: (uri, {line, column}) {},
      );
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in <double>[
        120,
        180,
        233.4,
        240,
        300,
        360,
        399,
        400,
        480,
        800,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 180,
                  child: Builder(builder: view.buildMain),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: 'width $width');
        expect(
          find.textContaining('Errors (', findRichText: true),
          findsOneWidget,
          reason: 'width $width: the filter chips are there',
        );
      }
    },
  );
}

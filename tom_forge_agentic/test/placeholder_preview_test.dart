// Tests for the reusable live placeholder preview (§11.5, §12, OE-14). The
// widget expands a placeholder-bearing string via an injected `compose` and
// must render an unsupported-expression error inline rather than crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  group('PlaceholderPreview (OE-14)', () {
    testWidgets('renders the composed expansion of a non-empty source',
        (tester) async {
      await _pump(
        tester,
        PlaceholderPreview(
          source: r'Hi ${name}!',
          compose: (s) => s.replaceAll(r'${name}', 'Alex'),
        ),
      );
      expect(find.text('Hi Alex!'), findsOneWidget);
    });

    testWidgets('renders the empty hint when the source is blank',
        (tester) async {
      await _pump(
        tester,
        PlaceholderPreview(
          source: '   ',
          compose: (s) => s,
          emptyHint: 'no preview',
        ),
      );
      expect(find.text('no preview'), findsOneWidget);
      expect(find.byKey(const Key('placeholder-preview-body')), findsNothing);
    });

    testWidgets('renders a thrown unsupported-expression error inline, not a '
        'crash', (tester) async {
      await _pump(
        tester,
        PlaceholderPreview(
          source: r'compute ${{ 1 + 1 }}',
          compose: (_) => throw PlaceholderExpressionsUnsupportedError('1 + 1'),
        ),
      );
      // The widget swallows the throw and surfaces its message in the preview.
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('PlaceholderExpressionsUnsupportedError'),
        findsOneWidget,
      );
    });
  });
}

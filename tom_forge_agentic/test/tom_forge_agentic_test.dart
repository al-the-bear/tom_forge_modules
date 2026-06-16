import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_forge_agentic/tom_forge_agentic.dart';

void main() {
  testWidgets('AgentPanelPlaceholder renders title and previewed status',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgentPanelPlaceholder(
            title: 'Chat',
            status: 'Connect to a workspace to begin.',
          ),
        ),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Connect to a workspace to begin.'), findsOneWidget);
  });

  testWidgets('AgentPanelPlaceholder truncates long status via textPreview',
      (tester) async {
    final longStatus = 'x' * 300;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AgentPanelPlaceholder(status: longStatus)),
      ),
    );

    // The shared textPreview helper caps at the requested limit (120) plus the
    // ellipsis, so the full 300-char string must not be rendered verbatim.
    expect(find.text(longStatus), findsNothing);
  });
}

// Widget tests for the §11.1/§11.5 composer affordances added in OE-14: the
// profile picker dropdown and the inline live placeholder preview. The send
// pipeline itself is covered by send_test.dart; here we only need a controller
// to construct the panel, never to send.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';

SpecSessionStore _tempSessionStore() {
  final dir = Directory.systemTemp.createTempSync('tom_specs_composer_session');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return SpecSessionStore(File('${dir.path}/agent_session.yaml'));
}

AgentConnectionController _connection() {
  final dir = Directory.systemTemp.createTempSync('tom_specs_composer_bridge');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final store = BridgeChoiceStore(File('${dir.path}/bridge_connection.yaml'))
    ..save(const BridgeChoice(host: '127.0.0.1', port: 19900));
  return AgentConnectionController(
    service: BridgeConnectionService(
      scanner: ({required host, required minPort, required maxPort}) async =>
          const {},
    ),
    store: store,
  )..loadPersisted();
}

AgentSendController _sendController() => AgentSendController(
      connection: _connection(),
      sessionStore: _tempSessionStore(),
    );

Future<void> _pump(WidgetTester tester, ChatComposerPanel panel) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: panel)));

void main() {
  group('ChatComposerPanel profile picker (§11.1, OE-14)', () {
    testWidgets('hides the picker when no profiles are supplied',
        (tester) async {
      await _pump(
        tester,
        ChatComposerPanel(
          controller: _sendController(),
          onSendNow: (_) {},
          onAddToQueue: (_) {},
        ),
      );
      expect(find.byKey(const Key('chat-composer-profile')), findsNothing);
    });

    testWidgets('shows the picker and routes a selection to the host',
        (tester) async {
      String? picked = 'sentinel';
      await _pump(
        tester,
        ChatComposerPanel(
          controller: _sendController(),
          onSendNow: (_) {},
          onAddToQueue: (_) {},
          profiles: const [
            ChatComposerProfile(id: 'p1', name: 'Engineer'),
            ChatComposerProfile(id: 'p2', name: 'Reviewer'),
          ],
          onProfileSelected: (id) => picked = id,
        ),
      );

      expect(find.byKey(const Key('chat-composer-profile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-composer-profile')));
      await tester.pumpAndSettle();
      // Pick "Reviewer" from the opened menu (last match is the menu item).
      await tester.tap(find.text('Reviewer').last);
      await tester.pumpAndSettle();
      expect(picked, 'p2');
    });
  });

  group('ChatComposerPanel live preview (§11.5, OE-14)', () {
    testWidgets('hides the preview when no compose function is supplied',
        (tester) async {
      await _pump(
        tester,
        ChatComposerPanel(
          controller: _sendController(),
          onSendNow: (_) {},
          onAddToQueue: (_) {},
        ),
      );
      expect(find.byKey(const Key('chat-composer-preview')), findsNothing);
    });

    testWidgets('expands the typed placeholders in the live preview',
        (tester) async {
      await _pump(
        tester,
        ChatComposerPanel(
          controller: _sendController(),
          onSendNow: (_) {},
          onAddToQueue: (_) {},
          composePreview: (s) => s.replaceAll(r'${who}', 'Alex'),
        ),
      );

      await tester.enterText(find.byType(TextField), r'hi ${who}');
      await tester.pump();
      // Open the collapsible preview and read the expansion.
      await tester.tap(find.byKey(const Key('chat-composer-preview')));
      await tester.pumpAndSettle();
      expect(find.text('hi Alex'), findsOneWidget);
    });
  });
}

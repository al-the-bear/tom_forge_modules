// Tests for the editor agent send controller (§7): folding the engine's event
// stream into observable UI state, and the §7.2 session refresh, all over a
// faked SDK transport so the whole pipeline runs without a socket.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

/// A transport double that emits a scripted message sequence for every started
/// query (mirrors the engine-level test in tom_core_agentic). [script] maps the
/// `startQuery` params (carrying the serialized `options`, including `resume`)
/// to the raw `SDKMessage` JSON maps to stream back, in order.
class _ScriptedTransport implements AgentSdkTransport {
  _ScriptedTransport(this.script);

  final List<Map<String, dynamic>> Function(Map<String, dynamic> params) script;

  final _chunks = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> started = [];

  @override
  Stream<Map<String, dynamic>> get chunks => _chunks.stream;

  @override
  Future<void> startQuery(Map<String, dynamic> params) async {
    started.add(params);
    final streamId = params['streamId'];
    final messages = script(params);
    unawaited(Future<void>(() async {
      for (final message in messages) {
        _chunks.add({'streamId': streamId, 'message': message});
      }
      _chunks.add({'streamId': streamId, 'done': true});
    }));
  }

  @override
  Future<void> cancelQuery(String streamId) async {}

  @override
  void registerTools(String streamId, AgentSdkToolRegistry registry) {}

  @override
  void unregisterTools(String streamId) {}

  @override
  void registerCanUseTool(String streamId, CanUseTool callback) {}

  @override
  void unregisterCanUseTool(String streamId) {}

  Future<void> dispose() => _chunks.close();
}

Map<String, dynamic> _assistant(String text) => {
      'type': 'assistant',
      'message': {
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
    };

Map<String, dynamic> _success(String sessionId) => {
      'type': 'result',
      'subtype': 'success',
      'is_error': false,
      'session_id': sessionId,
      'result': 'ok',
    };

Map<String, dynamic> _errorResult(String text) => {
      'type': 'result',
      'subtype': 'error_during_execution',
      'is_error': true,
      'result': text,
    };

String? _resumeOf(Map<String, dynamic> params) =>
    (params['options'] as Map?)?['resume'] as String?;

SpecSessionStore _tempSessionStore() {
  final dir = Directory.systemTemp.createTempSync('tom_specs_send_session');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return SpecSessionStore(File('${dir.path}/agent_session.yaml'));
}

/// A connection controller, optionally bound to 127.0.0.1:19900, without
/// scanning sockets.
AgentConnectionController _connection({bool bound = true}) {
  final dir = Directory.systemTemp.createTempSync('tom_specs_send_bridge');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final store = BridgeChoiceStore(File('${dir.path}/bridge_connection.yaml'));
  if (bound) {
    store.save(const BridgeChoice(host: '127.0.0.1', port: 19900));
  }
  return AgentConnectionController(
    service: BridgeConnectionService(
      scanner: ({required host, required minPort, required maxPort}) async =>
          const {},
    ),
    store: store,
  )..loadPersisted();
}

void main() {
  group('AgentSendController.send', () {
    test('streams the answer into output and records the session id', () async {
      final transport =
          _ScriptedTransport((_) => [_assistant('hello'), _success('s-new')]);
      addTearDown(transport.dispose);

      final controller = AgentSendController(
        connection: _connection(),
        sessionStore: _tempSessionStore(),
        clientFactory: ({required host, required port}) async =>
            AgentSdkClient(transport),
      );

      expect(controller.canSend, isTrue);
      await controller.send('hi');

      expect(controller.output, 'hello');
      expect(controller.sessionId, 's-new');
      expect(controller.sending, isFalse);
      expect(controller.error, isNull);
      // The query connected to the bound bridge.
      expect(transport.started, hasLength(1));
    });

    test('refreshes the session id on a session error and retries fresh',
        () async {
      final transport = _ScriptedTransport((params) {
        if (_resumeOf(params) == 'stale-id') {
          return [_errorResult('Session not found: invalid session id')];
        }
        return [_assistant('recovered'), _success('s-fresh')];
      });
      addTearDown(transport.dispose);

      final sessionStore = _tempSessionStore()..save('stale-id');
      final controller = AgentSendController(
        connection: _connection(),
        sessionStore: sessionStore,
        clientFactory: ({required host, required port}) async =>
            AgentSdkClient(transport),
      );

      await controller.send('hi');

      expect(controller.sessionRefreshed, isTrue);
      expect(controller.output, 'recovered');
      expect(controller.sessionId, 's-fresh');
      expect(sessionStore.load(), 's-fresh');
      // First attempt resumed the stale id; the retry was fresh.
      expect(transport.started, hasLength(2));
      expect(_resumeOf(transport.started[0]), 'stale-id');
      expect(_resumeOf(transport.started[1]), isNull);
    });

    test('with no bound connection sets an error and never connects', () async {
      var factoryCalled = false;
      final controller = AgentSendController(
        connection: _connection(bound: false),
        sessionStore: _tempSessionStore(),
        clientFactory: ({required host, required port}) async {
          factoryCalled = true;
          throw StateError('should not connect');
        },
      );

      expect(controller.canSend, isFalse);
      await controller.send('hi');

      expect(controller.error, isA<StateError>());
      expect(factoryCalled, isFalse);
    });
  });

  group('AgentSendPanel', () {
    testWidgets('renders the streamed answer and disables Send while busy',
        (tester) async {
      final transport =
          _ScriptedTransport((_) => [_assistant('streamed!'), _success('s1')]);
      addTearDown(transport.dispose);

      final controller = AgentSendController(
        connection: _connection(),
        sessionStore: _tempSessionStore(),
        clientFactory: ({required host, required port}) async =>
            AgentSdkClient(transport),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentSendPanel(controller: controller)),
        ),
      );

      // Type a prompt, then tap Send and let the turn finish on the real event
      // loop. Both the tap and the poll run inside runAsync so the faked
      // transport's real-async emits are delivered (a fake-async pump cannot
      // advance them, and polling outside the send's zone would deadlock).
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.send));
        while (controller.sending) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();

      expect(controller.output, 'streamed!');
      expect(controller.sending, isFalse);
      // The streamed answer is rendered in the read-only output area.
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'streamed!',
        ),
        findsOneWidget,
      );
    });
  });
}

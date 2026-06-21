// End-to-end proof for OE-10: an agent send brackets every document mutation
// it makes mid-stream into one undo group / one change-log turn.
//
// `ChatSendCoordinator` (tom_forge_agentic) is wired with the host's
// `SpecDocumentController.beginTurn`/`endTurn`, exactly as `SpecsEditorApp`
// wires it in production. A faked SDK transport mutates the shared document
// three times while the send is in flight (standing in for the §8 tools the
// agent would drive mid-turn). The whole exchange must collapse to a single
// undo step, while the individual edits stay inspectable in the change log.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
// The agent SDK transport/client types live in the scripting API; hide the
// duplicate QueuedPromptStatus this test never references.
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart'
    hide QueuedPromptStatus;

/// A trivial single-content-field model (mirrors undo_test.dart): the turn /
/// undo machinery operates purely on section-ID paths, so the schema shape is
/// irrelevant.
Map<String, dynamic> _model() => {
      'roots': [
        {'type': 'DemoDoc', 'title': 'Demo', 'sectionId': 'D00'},
      ],
      'classes': {
        'DemoDoc': {
          'name': 'DemoDoc',
          'sectionId': 'D00',
          'fields': [
            {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
          ],
        },
      },
    };

/// A transport that runs [onStream] (the mid-turn mutations) while the query is
/// in flight, then streams a success result so the send settles cleanly.
class _MutatingTransport implements AgentSdkTransport {
  _MutatingTransport(this.onStream);

  final void Function() onStream;
  final _chunks = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get chunks => _chunks.stream;

  @override
  Future<void> startQuery(Map<String, dynamic> params) async {
    final streamId = params['streamId'];
    unawaited(Future<void>(() async {
      // The agent "uses its tools" here — mutating the shared document while
      // the send is still awaiting its result.
      onStream();
      _chunks.add({
        'streamId': streamId,
        'message': {
          'type': 'result',
          'subtype': 'success',
          'is_error': false,
          'session_id': 's1',
          'result': 'ok',
        },
      });
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

AgentConnectionController _boundConnection(Directory dir) {
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

void main() {
  late Directory dir;

  SpecDocumentController makeController() => SpecDocumentController(
        modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_model())),
        review: ReviewStore(File('${dir.path}/review.yaml')),
      );

  setUp(() => dir = Directory.systemTemp.createTempSync('specs_turn_undo_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('an agent send collapses its mid-stream mutations into one undo turn',
      () async {
    final c = makeController();

    final transport = _MutatingTransport(() {
      c.setContent('D00-OVR', 'first');
      c.setContent('D00-OVR', 'second');
      c.setContent('D00-OVR', 'third');
    });
    addTearDown(transport.dispose);

    final send = AgentSendController(
      connection: _boundConnection(dir),
      sessionStore: SpecSessionStore(File('${dir.path}/agent_session.yaml')),
      clientFactory: ({required host, required port}) async =>
          AgentSdkClient(transport),
    );
    final trail = PromptTrailController(
      store: PromptTrailStore(File('${dir.path}/prompt_trail.yaml')),
    );

    // Wired exactly as SpecsEditorApp wires it: the coordinator brackets the
    // send with the host document controller's turn boundary.
    final coordinator = ChatSendCoordinator(
      send: send,
      trail: trail,
      onTurnBegin: c.beginTurn,
      onTurnEnd: c.endTurn,
    );

    await coordinator.sendNow('do the work');

    // All three edits landed and are individually inspectable...
    expect(c.content('D00-OVR'), 'third');
    expect(c.changeLog.length, 3);
    // ...but they belong to a single turn, keyed by the trail pair id.
    expect(c.changeLog.groups, hasLength(1));
    expect(c.changeLog.groups.single.turnId, trail.pairs.single.id);

    // A single undo reverts the whole turn — the turn boundary closed (no
    // dangling open group), so the composite entry is on the undo stack.
    await c.undo();
    expect(c.content('D00-OVR'), isNull);
    expect(c.canUndo, isFalse);
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// A [BridgeConnectionService] that returns a fixed `port → workspace` table
/// without opening sockets. The default table mirrors the spec's test
/// assumption: a single live server on 19900.
BridgeConnectionService _fakeService({
  Map<int, String> table = const {19900: 'tom_agent_container'},
}) {
  return BridgeConnectionService(
    scanner: ({required host, required minPort, required maxPort}) async =>
        table,
  );
}

/// An in-memory-ish store backed by a temp file, so persistence is exercised
/// without touching the developer's real sidecar.
/// A BridgeChoiceStore over a fresh in-memory workspace.
BridgeChoiceStore _tempStore() =>
    BridgeChoiceStore.resolveDefault(TomMemoryFileSystem());

void main() {
  group('AgentChatModule', () {
    test('exposes a chat view over its connection controller', () {
      final module = AgentChatModule(
        fileSystem: TomMemoryFileSystem(),
        controller: AgentConnectionController(
          service: _fakeService(),
          store: _tempStore(),
        ),
      );

      expect(module.chatView, isNotNull);
      expect(module.views, contains(module.chatView));
      expect(module.displayName, 'Agent Chat');
    });

    test('exposes the queue (Col 2) and trail (Col 3) editors (§5, OE-9)', () {
      final module = AgentChatModule(
        fileSystem: TomMemoryFileSystem(),
        controller: AgentConnectionController(
          service: _fakeService(),
          store: _tempStore(),
        ),
      );

      // The queue and trail are middle-panel editors, not stacked inside the
      // bottom chat view — they render their respective controllers.
      expect(module.queueEditor, isA<PromptQueueEditor>());
      expect(module.trailEditor, isA<PromptTrailEditor>());
      expect(module.queueEditor.controller, same(module.queueController));
      expect(module.trailEditor.controller, same(module.trailController));
      // Both are advertised as the module's editors so the shell can host them.
      expect(
        module.editors,
        containsAll(<ForgeEditor>[module.queueEditor, module.trailEditor]),
      );
    });
  });
}

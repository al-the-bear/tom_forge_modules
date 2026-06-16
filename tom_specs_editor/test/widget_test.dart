// Smoke tests for the TomSpecs Editor shell.
//
// Step 8 verified the app launches a Forge shell. Step 9 adds the
// SpecsShellModule: three registered applications (DocSpecs / CodeSpecs /
// Implementation) with the 4-region layout, only DocSpecs functional.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'package:tom_specs_editor/src/specs_editor_app.dart';
import 'package:tom_specs_editor/src/specs_shell_module.dart';

/// An [AgentChatModule] whose controller scans a fixed table instead of opening
/// real sockets, so the smoke test leaves no pending socket timers.
AgentChatModule _fakeChatModule() {
  final dir = Directory.systemTemp.createTempSync('tom_specs_editor_widget');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return AgentChatModule(
    controller: AgentConnectionController(
      service: BridgeConnectionService(
        scanner: ({required host, required minPort, required maxPort}) async =>
            const {19900: 'tom_agent_container'},
      ),
      store: BridgeChoiceStore(File('${dir.path}/bridge_connection.yaml')),
    ),
  );
}

void main() {
  testWidgets('SpecsEditorApp launches a Forge shell on DocSpecs', (
    tester,
  ) async {
    // The Forge shell is a desktop IDE layout; give it a realistic window so
    // its toolbar/panels lay out without a (cosmetic) overflow at the tiny
    // 800x600 default test surface.
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(SpecsEditorApp(chatModule: _fakeChatModule()));
    await tester.pump();

    // The standard Forge shell scaffold is mounted — the app is a Forge shell,
    // not a bare MaterialApp.
    expect(find.byType(ForgeShellScaffold), findsOneWidget);
    // No FlutterError was thrown while building the layout.
    expect(tester.takeException(), isNull);
  });

  test('SpecsShellModule registers DocSpecs/CodeSpecs/Implementation', () {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = SpecsShellModule();
    module.activate(shell);

    final titles = module.applications.map((a) => a.title).toList();
    expect(titles, ['DocSpecs', 'CodeSpecs', 'Implementation']);

    // The shell's system state holds the same set and DocSpecs is active.
    final systemState = shell.systemState as DefaultSystemState;
    expect(
      systemState.applications.map((a) => a.title).toList(),
      ['DocSpecs', 'CodeSpecs', 'Implementation'],
    );
    expect(systemState.activeApplication.title, 'DocSpecs');
  });

  test('DocSpecs exposes all four regions; others reuse the skeleton', () {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = SpecsShellModule();
    module.activate(shell);

    final docSpecs = module.docSpecs;
    final layout = docSpecs.layout;
    // Three middle splits: Document, Queue, Trail.
    expect(layout.middlePanels.length, 3);
    // Each surrounding region carries a populated tab.
    expect(layout.leftPanel.tabs, isNotEmpty);
    expect(layout.rightPanel.tabs, isNotEmpty);
    expect(layout.bottomPanel.tabs, isNotEmpty);

    // CodeSpecs / Implementation reuse the skeleton with an empty document
    // editor and no side/bottom tabs.
    final codeSpecs = module.applications[1];
    expect(codeSpecs.title, 'CodeSpecs');
    expect(codeSpecs.layout.middlePanels.length, 1);
    expect(codeSpecs.layout.leftPanel.tabs, isEmpty);
    expect(codeSpecs.layout.bottomPanel.tabs, isEmpty);
  });
}

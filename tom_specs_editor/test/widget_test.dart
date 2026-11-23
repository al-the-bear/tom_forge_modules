// Smoke tests for the TomSpecs Editor shell.
//
// Step 8 verified the app launches a Forge shell. Step 9 adds the
// SpecsShellModule: three registered applications (DocSpecs / CodeSpecs /
// Implementation) with the 4-region layout, only DocSpecs functional.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultShellApi, DefaultSystemState, ForgeShellScaffold;

import 'package:tom_specs_editor/src/apps/phase_overview.dart';
import 'package:tom_specs_editor/src/apps/phase_surfaces.dart';
import 'package:tom_specs_editor/src/apps/spec_phase.dart';
import 'package:tom_specs_editor/src/specs_editor_app.dart';
import 'package:tom_specs_editor/src/specs_shell_module.dart';

/// An [AgentChatModule] whose controller scans a fixed table instead of opening
/// real sockets, so the smoke test leaves no pending socket timers.
AgentChatModule _fakeChatModule() {
  final workspace = TomMemoryFileSystem();
  return AgentChatModule(
    fileSystem: workspace,
    controller: AgentConnectionController(
      service: BridgeConnectionService(
        scanner: ({required host, required minPort, required maxPort}) async =>
            const {19900: 'tom_agent_container'},
      ),
      store: BridgeChoiceStore.resolveDefault(workspace),
    ),
  );
}

/// A workspace in memory that records which files are read.
class _RecordingWorkspace extends TomMemoryFileSystem {
  _RecordingWorkspace({super.seed});

  final reads = <String>[];

  @override
  Future<String> readText(Uri uri) {
    reads.add(pathOf(uri) ?? '$uri');
    return super.readText(uri);
  }
}

void main() {
  testWidgets('SpecsEditorApp starts over its workspace file system: the '
      'shell is that file system, the review file and the preferences are '
      'read through it, and a progress indicator shows until they are', (
    tester,
  ) async {
    // The Forge shell is a desktop IDE layout; give it a realistic window so
    // its toolbar/panels lay out without a (cosmetic) overflow at the tiny
    // 800x600 default test surface.
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = _RecordingWorkspace(
      seed: {
        'review/structure_review.yaml': 'version: 1\nentries:\n  {}\n',
        'prefs/editor.yaml':
            'version: 1\npreferences:\n  strictHeadlineEditing: false\n',
      },
    );
    await tester.pumpWidget(
      SpecsEditorApp(
        fileSystem: workspace,
        environment: const {'TOM_SPECS_PREFS_FILE': 'prefs/editor.yaml'},
        chatModule: _fakeChatModule(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    // The standard Forge shell scaffold is mounted — the app is a Forge shell,
    // not a bare MaterialApp.
    final scaffold = tester.widget<ForgeShellScaffold>(
      find.byType(ForgeShellScaffold),
    );
    expect(scaffold.shell.fileSystem, same(workspace));
    expect(
      workspace.reads,
      containsAll(['review/structure_review.yaml', 'prefs/editor.yaml']),
    );
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
    expect(systemState.applications.map((a) => a.title).toList(), [
      'DocSpecs',
      'CodeSpecs',
      'Implementation',
    ]);
    expect(systemState.activeApplication!.title, 'DocSpecs');
  });

  test('DocSpecs exposes all four regions; phase-2 apps mirror the skeleton', () {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = SpecsShellModule();
    module.activate(shell);

    final docSpecs = module.docSpecs;
    final layout = docSpecs.panelLayout;
    // Three middle splits: Document, Queue, Trail.
    expect(layout.middlePanels.length, 3);
    // Each surrounding region carries a populated tab.
    expect(layout.leftPanel.tabs, isNotEmpty);
    expect(layout.rightPanel.tabs, isNotEmpty);
    expect(layout.bottomPanel.tabs, isNotEmpty);

    // OE-26: CodeSpecs / Implementation now carry the same 4-region skeleton as
    // DocSpecs. The document split is the read-only phase overview; the left
    // panel adds an "Overview" tab; and the chat (bottom), change-log (right)
    // and queue/trail (middle Col 2/3) surfaces are present as phase-aware
    // placeholders (not the live DocSpecs instances — that follows OE-24a).
    for (final i in [1, 2]) {
      final app = module.applications[i];
      // Three middle splits: phase overview + queue/trail surface placeholders.
      expect(
        app.panelLayout.middlePanels.length,
        3,
        reason: '${app.title} middle',
      );
      expect(
        app.panelLayout.middlePanels[0].tabs.single.editor,
        isA<PhaseOverviewEditor>(),
        reason: '${app.title} document split',
      );
      expect(
        app.panelLayout.middlePanels[1].tabs.single.editor,
        isA<PhaseSurfaceEditor>(),
        reason: '${app.title} queue split',
      );
      expect(
        app.panelLayout.middlePanels[2].tabs.single.editor,
        isA<PhaseSurfaceEditor>(),
        reason: '${app.title} trail split',
      );
      // Left panel: only the "Overview" tab (Navigator/Structure/Config stay
      // DocSpecs-only — they drive the live document).
      expect(app.panelLayout.leftPanel.tabs, hasLength(1));
      expect(app.panelLayout.leftPanel.tabs.single.title, 'Overview');
      // Bottom "Chat" + right "Change Log" surfaces are no longer empty.
      expect(app.panelLayout.bottomPanel.tabs.single.title, 'Chat');
      expect(
        app.panelLayout.bottomPanel.tabs.single.sections.single,
        isA<PhaseSurfaceView>(),
      );
      expect(app.panelLayout.rightPanel.tabs.single.title, 'Change Log');
      expect(
        app.panelLayout.rightPanel.tabs.single.sections.single,
        isA<PhaseSurfaceView>(),
      );
    }

    expect(module.applications[1].title, 'CodeSpecs');
    expect(module.applications[2].title, 'Implementation');
  });

  testWidgets('a phase-2 surface names when it activates (OE-26)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhaseSurfaceBody(
            phase: SpecPhase.codeSpecs,
            surface: PhaseSurface.chat,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Truthful caption — names the surface and its phase-2 activation, not a
    // bare "not wired yet".
    expect(find.text('Chat'), findsOneWidget);
    expect(
      find.textContaining('Activates with the CodeSpecs document editor'),
      findsOneWidget,
    );
  });

  test('injected queue/trail land in DocSpecs middle Col 2 / Col 3 (OE-9)', () {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final chatModule = _fakeChatModule();
    final module = SpecsShellModule(
      queueEditor: chatModule.queueEditor,
      trailEditor: chatModule.trailEditor,
    );
    module.activate(shell);

    final middle = module.docSpecs.panelLayout.middlePanels;
    expect(middle, hasLength(3));
    // Col 1 = Document; Col 2 = the real prompt queue; Col 3 = the real trail —
    // no longer the placeholder stubs, and no longer stacked in the bottom chat
    // view.
    expect(middle[1].tabs.single.editor, same(chatModule.queueEditor));
    expect(middle[2].tabs.single.editor, same(chatModule.trailEditor));
  });

  testWidgets('CodeSpecs phase overview renders authentic Phase 4 content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PhaseOverviewBody(phase: SpecPhase.codeSpecs)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The real Phase-4 heading, a produced artifact, and a sourced component
    // are all rendered — this is genuine methodology content, not a placeholder.
    expect(find.textContaining('CodeSpecs'), findsWidgets);
    expect(find.textContaining('Phase 4'), findsWidgets);
    expect(find.textContaining('Skeletal application'), findsWidgets);
    expect(find.textContaining('UI Elements'), findsWidgets);
  });
}

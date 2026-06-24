import 'dart:io';

import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_spec_engine/scripting.dart' show SpecFileFacade;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../document/spec_document_controller.dart';
import '../structure/review_store.dart';
import '../structure/spec_model.dart';
import 'spec_agent_tools.dart';
import 'spec_engine_tools.dart';
import 'spec_memory_plane.dart';
import 'spec_script_runner.dart';

/// Forge module owning the agent's navigation/mutation tools (§8).
///
/// It builds the shared [SpecDocumentController] (over the supplied model future
/// and the shared [ReviewStore]) and the in-process MCP server that exposes the
/// §8 tools. The host wires [servers] into the agent send config's `mcpServers`
/// seam so the Agent SDK can call the tools mid-turn; all calls land on the same
/// controller the document UI uses, keeping agent and human edits coherent.
///
/// The module contributes no views/editors of its own — it is a pure capability
/// provider — so it slots into the registry alongside the structure and chat
/// modules without touching the layout.
///
/// Beyond the single-shot §8 tools it also owns the in-process [scriptRunner]
/// (§3, §8.1): the engine's D4rt scripting surface bound to the *same*
/// [controller], so an agent script and a tool both mutate one document and land
/// in the one change log / undo stack (§5). The engine is linked in-process via
/// its Flutter-safe `package:tom_spec_engine/scripting.dart` facade — no IPC.
class AgentToolsModule extends ForgeModule {
  AgentToolsModule({
    required Future<SpecModel> modelFuture,
    required ReviewStore review,
    SpecDocumentController? controller,
    this.serverName = 'tomspecs',
    String? scriptWorkspaceRoot,
  }) : controller = controller ??
            SpecDocumentController(
              modelFuture: modelFuture,
              review: review,
            ) {
    final workspaceRoot = scriptWorkspaceRoot ?? Directory.current.path;
    _server = SpecAgentTools(this.controller).buildServer(name: serverName);
    memoryPlane = SpecMemoryPlane(
      controller: this.controller,
      workspaceRoot: workspaceRoot,
    );
    scriptRunner = SpecScriptRunner(
      controller: this.controller,
      workspaceRoot: workspaceRoot,
      extraScopes: [memoryPlane.scriptScope],
    );
    _engineServer = SpecEngineTools(
      controller: this.controller,
      facade: SpecFileFacade(workspaceRoot: workspaceRoot),
      scriptTools: scriptRunner.tools,
      memoryTools: memoryPlane.tools,
      ensureMemoryWarm: memoryPlane.ensureWarm,
    ).buildServer(name: engineServerName);
  }

  /// The MCP server name exposed to the Agent SDK.
  final String serverName;

  /// The MCP server name for the reusable engine toolsets (`doc_*` / `file_*` /
  /// `script_*`), kept distinct from [serverName] so the two surfaces stay
  /// cleanly namespaced.
  final String engineServerName = 'tomspecs-engine';

  /// The shared document controller every tool reads/mutates through.
  final SpecDocumentController controller;

  /// The in-process D4rt scripting surface bound to [controller] (§8.1). Scripts
  /// it runs mutate the same document the §8 tools do, so the change log and undo
  /// see script and tool edits identically (§5).
  late final SpecScriptRunner scriptRunner;

  /// The embeddable memory plane (followup item 6): the live two-tier recall
  /// behind the `memory` script scope and the `mem_*` tools. Runs tier-1-only
  /// when the `vec0` binary is absent ([SpecMemoryPlane.available] is `false`).
  late final SpecMemoryPlane memoryPlane;

  late final McpSdkServerConfig _server;

  /// The engine toolsets server (DocTools / FileTools / ScriptTools / MemoryTools
  /// wrapped as MCP tools; followup items 5 + 6). The `mem_*` tools are now live
  /// via the in-editor [memoryPlane].
  late final McpSdkServerConfig _engineServer;

  /// The `mcpServers` map to fold into the agent send config (§7.2) — the editor's
  /// bespoke §8 tools plus the reusable engine toolsets.
  Map<String, McpServerConfig> get servers => {
        serverName: _server,
        engineServerName: _engineServer,
      };

  @override
  String get displayName => 'TomSpecs Agent Tools';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

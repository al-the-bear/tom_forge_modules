import 'dart:io';

import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show ForgeModule, ForgeShellApi;
import 'package:tom_spec_engine/agent.dart' show AgentToolGroup;
import 'package:tom_spec_engine/agent_runtime.dart' show ConversationalDriver;
import 'package:tom_spec_engine/scripting.dart' show SpecFileFacade;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../document/spec_document_controller.dart';
import '../structure/review_store.dart';
import '../structure/spec_model.dart';
import 'spec_agent_tools.dart';
import 'spec_brain_runtime.dart';
import 'spec_brain_tools.dart';
import 'spec_conversational_runtime.dart';
import 'spec_conversational_tools.dart';
import 'spec_engine_tools.dart';
import 'spec_memory_plane.dart';
import 'spec_script_runner.dart';

/// Forge module owning the agent's navigation/mutation tools
/// (`tom_specs_editor_specification.md` §8).
///
/// It builds the shared [SpecDocumentController] (over the supplied model
/// future and the shared [ReviewStore]) and the in-process MCP server that
/// exposes the `tom_specs_editor_specification.md` §8 tools. The host wires
/// [servers] into the agent send config's `mcpServers` seam so the Agent SDK
/// can call the tools mid-turn; all calls land on the same controller the
/// document UI uses, keeping agent and human edits coherent.
///
/// The module contributes no views/editors of its own — it is a pure capability
/// provider — so it slots into the registry alongside the structure and chat
/// modules without touching the layout.
///
/// Beyond the single-shot `tom_specs_editor_specification.md` §8 tools it also
/// owns the in-process [scriptRunner] (`llm_and_d4rt_tools.md` §3, §8.1): the
/// engine's D4rt scripting surface bound to the *same* [controller], so an
/// agent script and a tool both mutate one document and land in the one change
/// log / undo stack (`llm_and_d4rt_tools.md` §5). The engine is linked
/// in-process via its Flutter-safe `package:tom_spec_engine/scripting.dart`
/// facade — no IPC.
class AgentToolsModule extends ForgeModule {
  AgentToolsModule({
    required Future<SpecModel> modelFuture,
    required ReviewStore review,
    SpecDocumentController? controller,
    this.serverName = 'tomspecs',
    String? scriptWorkspaceRoot,
    ConversationalDriver? conversationalDriver,
    bool enableProviderEmbeddings = false,
    List<String> assetDirs = const [],
  }) : controller =
           controller ??
           SpecDocumentController(modelFuture: modelFuture, review: review) {
    final workspaceRoot = scriptWorkspaceRoot ?? Directory.current.path;
    // One audited file facade is shared by the engine `file_*` tools and the
    // live mode-(b) runtime's `file_*` surface, so an agent run reads/writes
    // through the same boundary as a direct tool call. The profile's opt-in
    // asset directories become extra read-only `file_find` roots (item 18).
    final facade = SpecFileFacade(
      workspaceRoot: workspaceRoot,
      assetDirs: assetDirs,
    );
    _server = SpecAgentTools(this.controller).buildServer(name: serverName);
    memoryPlane = SpecMemoryPlane(
      controller: this.controller,
      workspaceRoot: workspaceRoot,
      // Off by default so headless/test hosts use the deterministic hash
      // embedder; a live editor host opts in to provider-backed embeddings.
      enableProviderEmbeddings: enableProviderEmbeddings,
    );
    scriptRunner = SpecScriptRunner(
      controller: this.controller,
      workspaceRoot: workspaceRoot,
      extraScopes: [memoryPlane.scriptScope],
    );
    _engineServer = SpecEngineTools(
      controller: this.controller,
      facade: facade,
      scriptTools: scriptRunner.tools,
      memoryTools: memoryPlane.tools,
      ensureMemoryWarm: memoryPlane.ensureWarm,
    ).buildServer(name: engineServerName);
    brainRuntime = SpecBrainRuntime(
      controller: this.controller,
      memoryPlane: memoryPlane,
      facade: facade,
    );
    _brainServer = SpecBrainTools(
      brainRuntime,
    ).buildServer(name: brainServerName);
    conversationalRuntime = SpecConversationalRuntime(
      controller: this.controller,
      memoryPlane: memoryPlane,
      facade: facade,
      driver: conversationalDriver,
    );
    _converseServer = SpecConversationalTools(
      conversationalRuntime,
    ).buildServer(name: converseServerName);
  }

  /// The MCP server name exposed to the Agent SDK.
  final String serverName;

  /// The MCP server name for the reusable engine toolsets (`doc_*` / `file_*` /
  /// `script_*`), kept distinct from [serverName] so the two surfaces stay
  /// cleanly namespaced.
  final String engineServerName = 'tomspecs-engine';

  /// The MCP server name for the live mode-(b) agent runtime (`agent_run` /
  /// `agent_trail`; followup item 8), kept distinct from the other surfaces.
  final String brainServerName = 'tomspecs-brain';

  /// The MCP server name for the live mode-(a) conversational runtime
  /// (`converse_run` / `converse_trail`; followup item 9), kept distinct from
  /// the other surfaces.
  final String converseServerName = 'tomspecs-converse';

  /// The shared document controller every tool reads/mutates through.
  final SpecDocumentController controller;

  /// The in-process D4rt scripting surface bound to [controller]
  /// (`llm_and_d4rt_tools.md` §8.1). Scripts it runs mutate the same document
  /// the `tom_specs_editor_specification.md` §8 tools do, so the change log and
  /// undo see script and tool edits identically (`llm_and_d4rt_tools.md` §5).
  late final SpecScriptRunner scriptRunner;

  /// The embeddable memory plane (followup item 6): the live two-tier recall
  /// behind the `memory` script scope and the `mem_*` tools. Runs tier-1-only
  /// when the `vec0` binary is absent ([SpecMemoryPlane.available] is `false`).
  late final SpecMemoryPlane memoryPlane;

  /// The live mode-(b) agent runtime (followup item 8): drives the complex agent
  /// procedure through the Tom Brain session envelope over [memoryPlane]'s store,
  /// recording each run (with effort metrics) into the document's named memory.
  /// Reports `available:false` when the memory store is degraded.
  late final SpecBrainRuntime brainRuntime;

  /// The live mode-(a) conversational runtime (followup item 9): drives the
  /// complex agent procedure across multiple turns chosen by the bound
  /// conversational driver, recalling the RAG memory before each turn. Reports
  /// `available:false` when no conversational driver is bound.
  late final SpecConversationalRuntime conversationalRuntime;

  /// Late-binds the live conversational [driver] onto [conversationalRuntime].
  ///
  /// The live driver wraps the chat send controller, which is built after this
  /// module (the send config folds in this module's MCP servers), so the app
  /// binds the decision-maker here once that controller exists. Tests inject the
  /// driver at construction via `conversationalDriver` instead.
  void bindConversationalDriver(ConversationalDriver driver) =>
      conversationalRuntime.bindDriver(driver);

  late final McpSdkServerConfig _server;

  /// The engine toolsets server (DocTools / FileTools / ScriptTools / MemoryTools
  /// wrapped as MCP tools; followup items 5 + 6). The `mem_*` tools are now live
  /// via the in-editor [memoryPlane].
  late final McpSdkServerConfig _engineServer;

  /// The live mode-(b) runtime server (`agent_run` / `agent_trail`; followup
  /// item 8) wrapping [brainRuntime].
  late final McpSdkServerConfig _brainServer;

  /// The live mode-(a) conversational runtime server (`converse_run` /
  /// `converse_trail`; followup item 9) wrapping [conversationalRuntime].
  late final McpSdkServerConfig _converseServer;

  /// The `mcpServers` map to fold into the agent send config
  /// (`tom_specs_editor_specification.md` §7.2) — the editor's bespoke
  /// `tom_specs_editor_specification.md` §8 tools plus the reusable engine
  /// toolsets.
  Map<String, McpServerConfig> get servers => {
    serverName: _server,
    engineServerName: _engineServer,
    brainServerName: _brainServer,
    converseServerName: _converseServer,
  };

  /// Which `llm_and_d4rt_tools.md` §8 [AgentToolGroup]s each MCP server in
  /// [servers] provides — the mapping the live agent profile (followup item 7)
  /// intersects with an [AgentContext]'s toolset to select the application's
  /// MCP surface.
  ///
  /// The bespoke `tomspecs` server carries the
  /// `tom_specs_editor_specification.md` §8 navigation/mutation tools (`doc` +
  /// `script`); the `tomspecs-engine` server carries the reusable DocTools /
  /// FileTools / ScriptTools / MemoryTools (all four groups); the
  /// `tomspecs-brain` (mode b) and `tomspecs-converse` (mode a, multi-turn)
  /// servers each drive a run that touches every plane (doc + memory + file +
  /// script), so they carry the full group set too. The servers are coarse —
  /// per-tool gating within a server is deferred; the engine's **toolset ⊆
  /// scopes** invariant is the real capability guarantee.
  Map<String, Set<AgentToolGroup>> get serverToolGroups => {
    serverName: const {AgentToolGroup.doc, AgentToolGroup.script},
    engineServerName: const {
      AgentToolGroup.doc,
      AgentToolGroup.file,
      AgentToolGroup.script,
      AgentToolGroup.memory,
    },
    brainServerName: const {
      AgentToolGroup.doc,
      AgentToolGroup.file,
      AgentToolGroup.script,
      AgentToolGroup.memory,
    },
    converseServerName: const {
      AgentToolGroup.doc,
      AgentToolGroup.file,
      AgentToolGroup.script,
      AgentToolGroup.memory,
    },
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

import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart';

import '../document/spec_document_controller.dart';
import '../structure/review_store.dart';
import '../structure/spec_model.dart';
import 'spec_agent_tools.dart';

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
class AgentToolsModule extends ForgeModule {
  AgentToolsModule({
    required Future<SpecModel> modelFuture,
    required ReviewStore review,
    SpecDocumentController? controller,
    this.serverName = 'tomspecs',
  }) : controller = controller ??
            SpecDocumentController(
              modelFuture: modelFuture,
              review: review,
            ) {
    _server = SpecAgentTools(this.controller).buildServer(name: serverName);
  }

  /// The MCP server name exposed to the Agent SDK.
  final String serverName;

  /// The shared document controller every tool reads/mutates through.
  final SpecDocumentController controller;

  late final McpSdkServerConfig _server;

  /// The `mcpServers` map to fold into the agent send config (§7.2).
  Map<String, McpServerConfig> get servers => {serverName: _server};

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

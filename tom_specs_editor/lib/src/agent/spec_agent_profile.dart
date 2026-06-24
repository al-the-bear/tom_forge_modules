// SpecAgentProfile / SpecAgentProfiles — the editor's live Tom Brain
// **profile binding** (followup item 7, plan 17, §11).
//
// §11 makes the *application* the unit of agent configuration: each application
// (DocSpecs / CodeSpecs / Implementation) is a Tom Brain **profile** whose
// prompt is its guidelines document, whose tools are its MCP surface, and whose
// enabled D4rt scripting surfaces are its scope profile (the Q1 mapping,
// decision F1). The engine carries the *value* — `AgentContext` — and the
// editor performs the *live binding* here: it resolves that value into the
// running send configuration the active application drives.
//
// This replaces the static `AgentSendConfig(mcpServers: …)` the editor used to
// build with no per-application differentiation. A `SpecAgentProfile` resolves
// three things from one `AgentContext`:
//
//   * the **prompt** — the application's guidelines document, expanded through
//     the editor's placeholder prompt registry (`${guidelines-<name>}`) into an
//     additive system prompt;
//   * the **MCP surface** — the subset of the editor's MCP servers whose tool
//     groups the context's `toolset` enables;
//   * the **scope profile** — the D4rt base-scope names the application enables.
//
// `SpecAgentProfiles` holds the per-application contexts (DocSpecs is the only
// authored one today — item 10 authors CodeSpecs / Implementation) and resolves
// the live profile by application name, falling back to the DocSpecs profile for
// an unauthored application so the editor always has a valid binding.

import 'package:tom_core_agentic/tom_core_agentic.dart' show AgentSendConfig;
import 'package:tom_spec_engine/agent.dart';
import 'package:tom_spec_engine/memory.dart' show MemoryScope;
import 'package:tom_vscode_scripting_api/tom_vscode_scripting_api.dart'
    show McpServerConfig, PermissionMode;

/// One application's live binding of an engine [AgentContext] onto the editor's
/// running resources: the resolved guidelines **prompt**, the enabled **MCP
/// surface**, and the application's **scope profile** (§11, item 7).
class SpecAgentProfile {
  /// Binds [context] to its already-resolved [systemPrompt] and [mcpServers].
  /// Built by [SpecAgentProfiles.profileFor]; not constructed directly by UI.
  SpecAgentProfile({
    required this.context,
    required this.systemPrompt,
    required Map<String, McpServerConfig> mcpServers,
  }) : mcpServers = Map.unmodifiable(mcpServers);

  /// The engine-plane value this profile binds — `{application, guidelines,
  /// toolset, scopeProfile}`.
  final AgentContext context;

  /// The additive system prompt resolved from the application's guidelines doc
  /// via the prompt registry. Empty when the doc is absent (the registry is
  /// lenient), in which case [buildSendConfig] sends no additive prompt.
  final String systemPrompt;

  /// The MCP servers the [context]'s [AgentContext.toolset] enables — the live
  /// tool surface the agent can call this application under.
  final Map<String, McpServerConfig> mcpServers;

  /// The Tom Brain profile this application binds to (= the application name).
  String get application => context.application;

  /// The D4rt base-scope names this application enables (§4 scope profile).
  List<String> get scopeNames =>
      context.scopeProfile.scopeNames.toList(growable: false);

  /// The §8 tool groups this application exposes.
  Set<AgentToolGroup> get toolset => context.toolset;

  /// Addresses one run's memory per the Q1 mapping (F1): this application's
  /// **profile** + a per-phase named [session] + a per-document named
  /// [document].
  MemoryScope memoryScope({
    required String session,
    required String document,
  }) =>
      context.memoryScope(session: session, document: document);

  /// Builds the send config the active application drives: the additive
  /// guidelines [systemPrompt] (omitted when empty) plus the enabled
  /// [mcpServers] (omitted when none). The global knobs ([model],
  /// [permissionMode], [maxTurns], [cwd]) pass through unchanged.
  AgentSendConfig buildSendConfig({
    String? model,
    PermissionMode? permissionMode,
    int? maxTurns,
    String? cwd,
  }) =>
      AgentSendConfig(
        model: model,
        systemPrompt: systemPrompt.isEmpty ? null : systemPrompt,
        permissionMode: permissionMode,
        maxTurns: maxTurns,
        cwd: cwd,
        mcpServers: mcpServers.isEmpty ? null : mcpServers,
      );
}

/// Holds the per-application [AgentContext]s and resolves the live
/// [SpecAgentProfile] for an application — the §11 **application switch** made
/// live in the editor (item 7).
///
/// The MCP surface is derived by intersecting each context's
/// [AgentContext.toolset] with the [serverToolGroups] each editor MCP server
/// provides: a server is included iff the context enables at least one of the
/// tool groups that server exposes. The guidelines prompt is resolved by
/// composing the `${guidelines-<name>}` placeholder through the editor's prompt
/// [compose] registry.
class SpecAgentProfiles {
  /// Builds the resolver over the editor's live resources:
  ///   * [compose] — the placeholder prompt registry (the editor's
  ///     `SpecPromptComposer.compose`) used to expand the guidelines doc;
  ///   * [servers] — the editor's MCP servers (`AgentToolsModule.servers`);
  ///   * [serverToolGroups] — which §8 tool groups each server provides
  ///     (`AgentToolsModule.serverToolGroups`);
  ///   * [contexts] — the application contexts (defaults to a registry holding
  ///     the reference [docSpecsAgentContext]).
  SpecAgentProfiles({
    required String Function(String template) compose,
    required Map<String, McpServerConfig> servers,
    required Map<String, Set<AgentToolGroup>> serverToolGroups,
    AgentContextRegistry? contexts,
  })  : _compose = compose,
        _servers = Map.unmodifiable(servers),
        _serverToolGroups = Map.unmodifiable(serverToolGroups),
        _contexts = contexts ?? _defaultContexts();

  final String Function(String template) _compose;
  final Map<String, McpServerConfig> _servers;
  final Map<String, Set<AgentToolGroup>> _serverToolGroups;
  final AgentContextRegistry _contexts;
  final Map<String, SpecAgentProfile> _cache = {};

  static AgentContextRegistry _defaultContexts() =>
      AgentContextRegistry()..register(docSpecsAgentContext());

  /// Whether [application] has an authored context (vs. falling back to
  /// DocSpecs). Only DocSpecs is authored today (item 10 authors the rest).
  bool isAuthored(String application) => _contexts.has(application);

  /// The names of the applications with an authored context.
  Iterable<String> get authoredApplications => _contexts.applications;

  /// The DocSpecs profile — the reference application bound live.
  SpecAgentProfile get docSpecs => profileFor(docSpecsApplication);

  /// The live profile for [application]. An unauthored application falls back
  /// to the DocSpecs profile so the editor always has a valid binding (item 10
  /// replaces the fallback with the application's own context).
  SpecAgentProfile profileFor(String application) {
    final resolved =
        _contexts.has(application) ? application : docSpecsApplication;
    return _cache.putIfAbsent(resolved, () => _bind(_contexts.context(resolved)));
  }

  /// Resolves one [context] into a live [SpecAgentProfile].
  SpecAgentProfile _bind(AgentContext context) => SpecAgentProfile(
        context: context,
        systemPrompt: _resolvePrompt(context.guidelinesName),
        mcpServers: _selectServers(context.toolset),
      );

  /// Expands the application's guidelines doc into an additive prompt through
  /// the placeholder registry. `${guidelines-<name>}` reads
  /// `<workspace>/_copilot_guidelines/<name>.md`; a missing doc renders empty
  /// (lenient), yielding no additive prompt.
  String _resolvePrompt(String guidelinesName) =>
      _compose('\${guidelines-$guidelinesName}').trim();

  /// The MCP servers [toolset] enables: each server whose provided tool groups
  /// intersect the toolset.
  Map<String, McpServerConfig> _selectServers(Set<AgentToolGroup> toolset) {
    final selected = <String, McpServerConfig>{};
    _serverToolGroups.forEach((name, groups) {
      final server = _servers[name];
      if (server != null && groups.any(toolset.contains)) {
        selected[name] = server;
      }
    });
    return selected;
  }
}

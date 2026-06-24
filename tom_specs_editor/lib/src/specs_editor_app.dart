import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_agentic/tom_forge_agentic.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'agent/agent_tools_module.dart';
import 'agent/spec_agent_profile.dart';
import 'agent/spec_prompt_composer.dart';
import 'config/raw_file_module.dart';
import 'config/specs_config_module.dart';
import 'document/root_navigator.dart';
import 'document/spec_document_controller.dart';
import 'document/spec_document_editor.dart';
import 'spec_structure_module.dart';
import 'specs_shell_module.dart';
import 'structure/review_store.dart';
import 'structure/spec_structure_view.dart';

/// Root widget for the TomSpecs Editor.
///
/// Step 9 registers the [SpecsShellModule], which contributes the three
/// top-level applications (DocSpecs / CodeSpecs / Implementation) and their
/// 4-region layouts (§4.2, §5). DocSpecs is shown on launch and is the only
/// functional one — its four regions are populated with placeholder
/// views/editors. The shell toolbar's application switcher lets the user move
/// between the three; selecting one calls [onApplicationSwitch], which
/// re-renders the scaffold with the chosen application's layout.
///
/// The spec-specific editors/views (structure browser, document editor, chat
/// suite, change log) arrive in later steps (10–18).
class SpecsEditorApp extends StatefulWidget {
  const SpecsEditorApp({super.key, this.chatModule});

  /// The agent chat module hosting the bottom-panel connection picker. The
  /// production app supplies its own (which scans 19900–19909 on launch);
  /// tests inject one whose controller wraps a fake service so no real sockets
  /// are opened.
  final AgentChatModule? chatModule;

  @override
  State<SpecsEditorApp> createState() => _SpecsEditorAppState();
}

class _SpecsEditorAppState extends State<SpecsEditorApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DefaultShellApi _shell;
  late final SpecStructureModule _structureModule;
  late final SpecDocumentController _documentController;
  late final AgentToolsModule _toolsModule;
  late final PromptTrailController _trailController;
  late final SpecPromptComposer _promptComposer;
  late final SpecAgentProfiles _agentProfiles;
  late final AgentChatModule _chatModule;
  late final RawFileModule _rawFileModule;

  /// The composer's currently-picked profile (§11.1, OE-14). The picker records
  /// the choice here; feeding it into the send `Options` (system prompt /
  /// max-tokens / interrupt-retry prefix) is a deferred settings concern
  /// (tracked in the OE-14 questions file).
  String? _selectedProfileId;
  late final SpecsConfigModule _configModule;
  late final SpecsShellModule _shellModule;
  late final ShellEditorIntegration _documentIntegration;
  late ForgeApplication _application;

  @override
  void initState() {
    super.initState();
    _shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: _navigatorKey,
    );

    // One shared model future + review store feeds the structure browser, the
    // agent tools, and the document controller, so a review or document edit
    // from either the UI or the agent lands on the same state.
    final modelFuture = loadSpecModelFromAsset();
    final reviewStore = ReviewStore.resolveDefault()..load();

    // The structure module owns the structure browser; it is registered first
    // so its view exists before the shell builds the DocSpecs layout that hosts
    // it as a panel tab. It shares the model future + review store.
    _structureModule = SpecStructureModule(
      modelFuture: modelFuture,
      store: reviewStore,
    );
    _structureModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_structureModule);

    // One document controller is shared by the agent tools (§8) and the
    // model-driven document editor (§13), so a mutation from either the UI or
    // the agent lands on the same live document and both re-render.
    _documentController = SpecDocumentController(
      modelFuture: modelFuture,
      review: reviewStore,
    );

    // The agent tools module owns the §8 navigation/mutation tools over the
    // shared document controller; its server config is folded into the agent
    // send config below so the embedded agent can call the tools mid-turn.
    _toolsModule = AgentToolsModule(
      modelFuture: modelFuture,
      review: reviewStore,
      controller: _documentController,
    );
    _toolsModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_toolsModule);

    // The prompt trail is constructed here (not left to the chat module's
    // default) so the §11.5 placeholder composer can read it for the `${chat}`
    // built-in (OE-12) — the composer is built *before* the chat module, so the
    // transcript source must exist first and be injected into the module.
    _trailController = PromptTrailController();

    // The §11.5 placeholder composer is built once and shared: the chat module
    // uses it to expand sent prompts and to drive the composer's live preview
    // (OE-14), and the config module uses it for the Prompt Templates / profile
    // "live placeholder preview" (§12, OE-14).
    _promptComposer = _buildPromptComposer();

    // The live Tom Brain profile binding (§11, item 7): per application, an
    // engine AgentContext resolved into the running send config — the
    // guidelines prompt (via the composer registry), the MCP surface its
    // toolset enables, and its scope profile. DocSpecs is the authored
    // reference (item 10 authors CodeSpecs / Implementation); it drives the
    // launch send config below, replacing the static placeholder.
    _agentProfiles = SpecAgentProfiles(
      compose: _promptComposer.compose,
      servers: _toolsModule.servers,
      serverToolGroups: _toolsModule.serverToolGroups,
    );

    // The agent chat module owns the bridge connection picker; it is registered
    // before the shell so its chat view exists when the DocSpecs bottom panel
    // is built. Activation kicks off the port scan (19900–19909). The send
    // controller carries the §8 tool server (mcpServers seam) unless a test
    // injects its own chat module.
    _chatModule = widget.chatModule ?? _buildChatModule();
    _chatModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_chatModule);

    // The config module (§12, step 18) hosts the seven custom config editors
    // and the basic-prefs settings panel; its raw-file module backs the
    // editors' "Open raw file" buttons. The raw-file module is registered and
    // activated first so it can route plain-text editors into the layout when a
    // config editor opens its backing YAML/markdown.
    _rawFileModule = RawFileModule();
    _rawFileModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_rawFileModule);

    _configModule = SpecsConfigModule(
      rawFileModule: _rawFileModule,
      compose: _promptComposer.compose,
    );
    _configModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_configModule);

    // The shell module registers the three applications and selects DocSpecs,
    // hosting the structure view as the DocSpecs left panel's "Structure" tab
    // and the agent chat view as the bottom panel's "Chat" tab.
    _shellModule = SpecsShellModule(
      structureView: _structureModule.structureView,
      chatView: _chatModule.chatView,
      documentEditor: SpecDocumentEditor(controller: _documentController),
      queueEditor: _chatModule.queueEditor,
      trailEditor: _chatModule.trailEditor,
      navigatorView: RootNavigator(controller: _documentController),
      // The dedicated config rail (§12, OE-16) — a left-panel launcher for the
      // seven config editors, hosted as the DocSpecs "Config" tab.
      configRailView: _configModule.configRailView,
    );
    _shellModule.activate(_shell);
    (_shell.modules as DefaultModuleRegistry).register(_shellModule);

    // Register the document editor's undo/redo with the shell (§10, OE-11) so
    // the global undo/redo affordances (action bar, Edit menu, shortcut) carry
    // their metadata and dispatch into the shared controller's snapshot stack.
    // The controller stays the single undo authority; the active editor's
    // EditorActionProvider (SpecDocumentEditor) drives enablement/execution. No
    // `notifyTextEdit` bridge entries are pushed onto the shell's own undo
    // manager — that would double-count the controller's stack.
    _documentIntegration = ShellEditorIntegration(
      shellApi: _shell,
      editorId: 'specs-document-editor',
      editorTypeId: 'specs-document',
    )..descriptors = StandardEditingActions.descriptors;
    _documentController.attachIntegration(_documentIntegration);

    // Start on DocSpecs — the one functional application.
    _application = _shellModule.docSpecs;
  }

  /// Builds the production chat module whose send controller carries the §8
  /// tool server in its `mcpServers`. The connection and send controllers are
  /// constructed explicitly so the same connection drives both, and the
  /// §11.5 placeholder composer is wired in so every sent prompt — from the
  /// composer or the queue — has its placeholders expanded first.
  AgentChatModule _buildChatModule() {
    final connection = AgentConnectionController();
    // The launch application is DocSpecs (§9), so its live profile drives the
    // send config: the additive guidelines prompt + the MCP surface its toolset
    // enables. Per-application reconfiguration on the shell's application switch
    // is deferred (the send controller's config is final — item 8/9; F7).
    final sendController = AgentSendController(
      connection: connection,
      config: _agentProfiles.docSpecs.buildSendConfig(),
    );
    // The composer profile picker (§11.1, OE-14): the persisted profiles mapped
    // to the composer's lightweight type, with the default profile pre-selected.
    final profiles = AgentProfileStore.resolveDefault().load();
    final pickerProfiles = [
      for (final profile in profiles)
        ChatComposerProfile(id: profile.id, name: profile.name),
    ];
    for (final profile in profiles) {
      if (profile.isDefault ?? false) {
        _selectedProfileId = profile.id;
        break;
      }
    }
    return AgentChatModule(
      controller: connection,
      sendController: sendController,
      trailController: _trailController,
      compose: _promptComposer.compose,
      // The live placeholder preview (OE-14) expands the same way the sent
      // prompt will, surfacing `${{…}}` as an inline error rather than a crash.
      composePreview: _promptComposer.compose,
      profiles: pickerProfiles,
      selectedProfileId: _selectedProfileId,
      onProfileSelected: (id) => _selectedProfileId = id,
      // Bracket each agent send as one turn on the shared document controller
      // (§9/§10, step 15) so every §8 tool mutation the agent makes mid-stream
      // collapses into a single undo group / change-log turn (OE-10).
      onTurnBegin: _documentController.beginTurn,
      onTurnEnd: _documentController.endTurn,
    );
  }

  /// Builds the §11.5 placeholder composer for the current workspace: the
  /// quest is the workspace folder name, file-injections resolve against its
  /// `_ai/` folder, and the user's persisted chat variables are bound.
  SpecPromptComposer _buildPromptComposer() {
    final workspace = Directory.current;
    return SpecPromptComposer(
      workspaceName: p.basename(workspace.path),
      aiFolder: Directory(p.join(workspace.path, '_ai')),
      variables: ChatVariableStore.resolveDefault().load(),
      // OE-12 host context: `${chat}` = the live trail transcript, `${file}` =
      // the active document rendered as markdown. Both are read at compose-time
      // and stay lenient-empty before the model loads / the trail has content.
      chatTranscript: () => _renderTranscript(_trailController.pairs),
      activeDocument: _renderActiveDocument,
    );
  }

  /// Renders the prompt trail as a plain-text transcript for the `${chat}`
  /// placeholder (OE-12): one `User:` / `Assistant:` block per pair in
  /// chronological order. Pairs whose answer is still streaming contribute only
  /// the request line.
  static String _renderTranscript(List<TrailPair> pairs) {
    final blocks = <String>[];
    for (final pair in pairs) {
      blocks.add('User: ${pair.request.text}');
      final answer = pair.answer;
      if (answer != null) blocks.add('Assistant: ${answer.text}');
    }
    return blocks.join('\n\n');
  }

  /// Renders the active document root as markdown for the `${file}` placeholder
  /// (OE-12). Returns empty before the model has loaded or when no concrete root
  /// is selected (the default-root case has no section id to export), so the
  /// slot stays lenient-empty rather than failing the compose.
  String _renderActiveDocument() {
    if (!_documentController.isModelLoaded) return '';
    final root = _documentController.activeRootType;
    if (root == null) return '';
    try {
      return _documentController.exportMarkdown(root);
    } on ArgumentError {
      return '';
    }
  }

  // The shell owns app-lifetime layout/system notifiers that the
  // [ForgeShellScaffold] subtree listens to; disposing it here would race the
  // framework's own teardown of those listeners. Like `tom_forge_app`, the
  // shell lives for the lifetime of the process and is not disposed per-widget.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _application.title,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ForgeShellScaffold(
        shell: _shell,
        application: _application,
        layoutController: _shell.layout as DefaultLayoutController,
        systemState: _shell.systemState as DefaultSystemState,
        statusBarController: _shell.statusBar,
        notificationManager:
            _shell.notifications as DefaultNotificationManager,
        onApplicationSwitch: (app) =>
            setState(() => _application = app),
      ),
    );
  }
}

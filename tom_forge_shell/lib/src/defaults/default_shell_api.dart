import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/text_types.dart'
    show ForgeTextSettings, StandardEditingActions;

import '../model/forge_application.dart';
import '../model/forge_config.dart';
import '../services/forge_environment.dart';
import '../services/forge_secret_storage.dart';
import '../services/forge_terminal_manager.dart';
import '../services/forge_virtual_document_manager.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_module_registry.dart';
import '../shell/forge_shell_components.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultExecutionMonitor, ForgeExecutionMonitor;
import 'package:tom_file_system/tom_file_system.dart'
    show TomFileSystem, TomMemoryFileSystem;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'default_layout_controller.dart';
import 'default_navigation_history.dart';
import 'default_module_registry.dart';
import 'default_status_bar_controller.dart';
import 'default_system_state.dart';
import 'stub_services.dart';
import '../shell/forge_tab_editor_host.dart';
import '../services/forge_preferences_service.dart';

/// Default implementation of [ForgeShellApi].
///
/// Aggregates all default service implementations and provides them
/// as a single API surface for module activation.
class DefaultShellApi implements ForgeShellApi {
  @override
  final ForgeSystemState systemState;

  @override
  ForgeSystemState get state => systemState;

  /// Editors are tabs of the middle panels ([ForgeTabEditorHost] over
  /// [layout]) unless the host gave an editor host of its own.
  @override
  final ForgeEditorHost editorHost;

  /// Where the preferences are kept: the store the host gave, else the
  /// shared_preferences store of [ForgePreferencesService.instance]. The
  /// scaffold reads its preferences from it
  /// ([ForgePreferencesService.forStore]) unless it is given a service.
  /// The workspace state keeps its own default, the `.forge/` files of the
  /// workspace ([DefaultWorkspaceStateManager]).
  @override
  final ForgeStateStore stateStore;

  @override
  final ForgeApplicationRegistry applications;

  @override
  final ForgeLayoutController layout;

  @override
  final ForgeNavigationHistory navigationHistory;

  @override
  final ForgeStatusBarController statusBar;

  @override
  final TomFileSystem fileSystem;

  @override
  final ForgeModuleRegistry modules;

  @override
  final ForgeOutputChannelManager output;

  @override
  final ForgeDiagnosticManager diagnostics;

  @override
  final ForgeConfigManager config;

  @override
  final ForgeNotificationManager notifications;

  @override
  final ForgeProgressManager progress;

  @override
  final ForgeDialogManager dialogs;

  @override
  final ForgeTerminalManager terminals;

  @override
  final ForgeClipboard clipboard;

  @override
  final ForgeEnvironment environment;

  @override
  final ForgeExecutionMonitor executions;

  @override
  final ForgeModuleStorage storage;

  @override
  final ForgeUndoManager undoManager;

  @override
  final ForgeSecretStorage secrets;

  @override
  final ForgeFileDecorationManager fileDecorations;

  @override
  final ForgeVirtualDocumentManager virtualDocuments;

  @override
  final ForgeOutlineManager outline;

  @override
  final ForgeSearchManager search;

  @override
  final ForgeActionRegistry actionRegistry;

  @override
  final ForgeShortcutManager shortcuts;

  @override
  final ForgeWorkspaceStateManager workspaceState;

  @override
  final ForgeContextMenuController contextMenus;

  /// The parts this shell was assembled from beyond its core: the terminal
  /// view the scaffold shows terminals with, the editor types the layout
  /// controller knows ([ForgeShellComponents]).
  final ForgeShellComponents components;

  final Map<String, ForgeTextSettings> _editorTextSettings = {};
  final Map<String, String> _fileTypeDefaults = {};

  DefaultShellApi({
    required this.systemState,
    required this.applications,
    required this.layout,
    required this.navigationHistory,
    required this.statusBar,
    required this.fileSystem,
    required this.modules,
    required this.output,
    required this.diagnostics,
    required this.config,
    required this.notifications,
    required this.progress,
    required this.dialogs,
    required this.terminals,
    required this.clipboard,
    required this.environment,
    required this.executions,
    required this.storage,
    required this.undoManager,
    required this.secrets,
    required this.fileDecorations,
    required this.virtualDocuments,
    required this.outline,
    required this.search,
    required this.actionRegistry,
    required this.shortcuts,
    ForgeWorkspaceStateManager? workspaceState,
    ForgeContextMenuController? contextMenus,
    ForgeShellComponents? components,
    ForgeEditorHost? editorHost,
    ForgeStateStore? stateStore,
  }) : components = components ?? ForgeShellComponents.registered,
       editorHost =
           editorHost ??
           ForgeTabEditorHost(layout: layout, systemState: systemState),
       stateStore = stateStore ?? ForgePreferencesService.instance.stateStore,
       workspaceState = workspaceState ?? DefaultWorkspaceStateManager(),
       contextMenus =
           contextMenus ??
           ForgeContextMenuController(
             modules: modules,
             actions: actionRegistry,
             moreContributions: () =>
                 applications.active?.contributions.contextMenus ?? const [],
           ) {
    _installStandardEditingActions();
    applications.listenable.addListener(_bindActiveContributions);
    _bindActiveContributions();
  }

  /// Registers the standard editing actions and binds their default keys, so
  /// the binding table holds the undo keys (and every other editing key)
  /// before any editor opens: one table, routed by [executeAction] to the
  /// active editor. A key already bound is left as it is.
  void _installStandardEditingActions() {
    final keys = StandardEditingActions.defaultShortcuts;
    for (final descriptor in StandardEditingActions.descriptors) {
      final id = descriptor.id;
      final key = keys[id];
      final action = ForgeAction(
        id: id,
        label: descriptor.label,
        icon: descriptor.icon,
        execute: (_) async {
          executeAction(id);
          return null;
        },
        isEnabled: () => isActionEnabled(id),
        isVisible: () => true,
        defaultShortcut: key,
      );
      if (actionRegistry.getAction(id) == null) {
        actionRegistry.registerAction(action);
      }
      final shortcut = action.defaultShortcut;
      if (shortcut != null && shortcuts.getBinding(id) == null) {
        shortcuts.rebind(action, shortcut);
      }
    }
  }

  /// The application whose contributions are bound now.
  ForgeApplication? _boundApplication;

  /// The action ids bound for [_boundApplication] — what an unbind removes.
  List<String> _boundActionIds = const [];

  /// Binds the active application's actions and shortcuts, unbinding the
  /// previous one's: an application action id resolves to the application on
  /// show. Runs on every change of the registry, so a switch, a close of the
  /// active application and the first add all rebind at once.
  ///
  /// An application action whose id is already registered (a module's) is not
  /// bound, nor is its shortcut: the module keeps the id, and the collision is
  /// reported as a Flutter error naming both, since it is a programming error
  /// a running shell cannot repair.
  void _bindActiveContributions() {
    final active = applications.active;
    if (identical(active, _boundApplication)) return;
    for (final id in _boundActionIds) {
      // Unbind, not removeBinding: a removed binding is the user's deletion
      // and would suppress every later application's key for the same id.
      shortcuts.unbind(id);
      actionRegistry.unregisterAction(id);
    }
    _boundApplication = active;
    final current = active?.contributions;
    final bound = <String>[];
    _boundActionIds = bound;
    if (current == null) return;
    for (final action in current.actions) {
      if (actionRegistry.getAction(action.id) != null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError(
              'application "${active!.id}" contributes action "${action.id}", '
              'which is already registered by a module; the application\'s '
              'action is not bound',
            ),
            library: 'tom_forge_ui',
            context: ErrorDescription(
              "while binding the active application's contributions",
            ),
          ),
        );
        continue;
      }
      actionRegistry.registerAction(action);
      bound.add(action.id);
    }
    for (final binding in current.shortcuts) {
      if (!bound.contains(binding.action.id)) continue;
      if (binding.isChord) {
        shortcuts.rebindChord(binding.action, binding.chord!);
      } else {
        shortcuts.rebind(binding.action, binding.key);
      }
    }
  }

  /// Creates a [DefaultShellApi] with all default implementations wired.
  ///
  /// [fileSystemSeed] populates the in-memory file system.
  /// [appName] is used as the application config name.
  /// [navigatorKey] enables dialog routing.
  /// [stateStore] keeps the preferences (default: shared_preferences).
  factory DefaultShellApi.withDefaults({
    required Map<String, String> fileSystemSeed,
    required String appName,
    required GlobalKey<NavigatorState> navigatorKey,
    ForgeConfig initialConfig = const ForgeConfig(),
    int maxOpenEditors = 20,
    ForgeShellComponents? components,
    ForgeStateStore? stateStore,
  }) {
    final memFs = TomMemoryFileSystem(seed: fileSystemSeed);
    return DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: memFs,
      appName: appName,
      navigatorKey: navigatorKey,
      initialConfig: initialConfig,
      maxOpenEditors: maxOpenEditors,
      components: components,
      stateStore: stateStore,
    );
  }

  /// Creates a [DefaultShellApi] with a custom [TomFileSystem].
  ///
  /// Use this factory when you need a real file system or custom implementation.
  /// [fileSystem] is the file system to use.
  /// [appName] is used as the application config name.
  /// [navigatorKey] enables dialog routing.
  /// [stateStore] keeps the preferences (default: shared_preferences).
  factory DefaultShellApi.withDefaultsAndFileSystem({
    required TomFileSystem fileSystem,
    required String appName,
    required GlobalKey<NavigatorState> navigatorKey,
    ForgeWorkspaceStateManager? workspaceState,
    ForgeModuleStorage? storage,
    ForgeConfig initialConfig = const ForgeConfig(),
    int maxOpenEditors = 20,
    ForgeShellComponents? components,
    ForgeStateStore? stateStore,
  }) {
    // The terminal manager, the secret storage, the terminal view and the
    // editor types beyond plain text: the ones given, else the registered.
    final parts = components ?? ForgeShellComponents.registered;
    final systemState = DefaultSystemState();
    final actionRegistry = DefaultActionRegistry();
    final shortcutManager = DefaultShortcutManager();
    final moduleRegistry = DefaultModuleRegistry(
      actionRegistry: actionRegistry,
      shortcutManager: shortcutManager,
    );
    final virtualDocumentManager = DefaultVirtualDocumentManager();
    final layoutController = DefaultLayoutController(
      systemState: systemState,
      fileSystem: fileSystem,
      moduleRegistry: moduleRegistry,
      virtualDocuments: virtualDocumentManager,
      maxOpenEditors: maxOpenEditors,
      editorTypes: parts.editorTypes,
    );
    final statusBarController = DefaultStatusBarController(
      registry: moduleRegistry,
      applications: systemState,
    );
    final diagnosticManager = DefaultDiagnosticManager(
      refreshDebounce: initialConfig.performance.diagnosticDebounceWindow,
    );
    final outputManager = DefaultOutputChannelManager();
    final configManager = DefaultConfigManager(initial: initialConfig);
    final notificationManager = DefaultNotificationManager();

    // Late-wire error-reporting services into the module registry so
    // activation/deactivation failures are reported to diagnostics,
    // notifications, and the output channel.
    moduleRegistry.diagnosticManager = diagnosticManager;
    moduleRegistry.notificationManager = notificationManager;
    moduleRegistry.outputManager = outputManager;
    moduleRegistry.systemState = systemState;

    // Late-wire diagnostics into the layout controller so fallback-editor
    // events emit an ED002 diagnostic.
    layoutController.diagnosticManager = diagnosticManager;
    layoutController.notificationManager = notificationManager;
    final navigationHistory = DefaultNavigationHistory(
      systemState: systemState,
      layout: layoutController,
    );
    layoutController.navigationHistory = navigationHistory;

    final progressManager = DefaultProgressManager();
    final dialogManager = DefaultDialogManager();
    final undoManager = DefaultUndoManager();
    final clipboardService = DefaultClipboard();

    // Every file system — a folder on disk, memory, the web — is searched
    // through the contract.
    final ForgeSearchManager searchManager = DefaultSearchManager(
      fileSystem: fileSystem,
    );

    final outlineManager = DefaultOutlineManager();
    final terminalManager = parts.terminalManagerFor(fileSystem);
    final storageService = storage ?? DefaultModuleStorage();
    final environmentService = DefaultEnvironment();
    final executionMonitor = DefaultExecutionMonitor();
    final secretStorage = parts.secretStorageFor(fileSystem);
    final fileDecorationManager = DefaultFileDecorationManager();

    // Auto-bridge: sync diagnostics from manager into system state so
    // status-bar items, event streams, and summary counters stay current.
    diagnosticManager.allNotifier.addListener(() {
      systemState.setDiagnostics(diagnosticManager.allNotifier.value);
    });

    return DefaultShellApi(
      systemState: systemState,
      applications: systemState,
      layout: layoutController,
      navigationHistory: navigationHistory,
      statusBar: statusBarController,
      fileSystem: fileSystem,
      modules: moduleRegistry,
      output: outputManager,
      diagnostics: diagnosticManager,
      config: configManager,
      notifications: notificationManager,
      progress: progressManager,
      dialogs: dialogManager,
      terminals: terminalManager,
      clipboard: clipboardService,
      environment: environmentService,
      executions: executionMonitor,
      storage: storageService,
      undoManager: undoManager,
      secrets: secretStorage,
      fileDecorations: fileDecorationManager,
      virtualDocuments: virtualDocumentManager,
      outline: outlineManager,
      search: searchManager,
      actionRegistry: actionRegistry,
      shortcuts: shortcutManager,
      workspaceState: workspaceState,
      components: parts,
      stateStore: stateStore,
    );
  }

  final Set<String> _executingActions = {};

  @override
  bool executeAction(String actionId) {
    // Handle wildcard action IDs (e.g. '*.deleteLine').
    if (actionId.startsWith('*.')) {
      return _executeWildcardAction(actionId);
    }

    // Guard against infinite recursion: if the action's execute callback
    // invokes executeAction with the same ID (e.g. placeholder editor
    // descriptor actions), bail out to prevent a stack overflow.
    if (_executingActions.contains(actionId)) {
      return false;
    }

    // Route standard editing actions through the active editor's
    // EditorActionProvider interface instead of the global registry.
    if (StandardEditingActions.standardActionIds.contains(actionId)) {
      final editor = systemState.activeEditor;
      if (editor != null && editor.isActionEnabled(actionId)) {
        _executingActions.add(actionId);
        try {
          return editor.executeAction(actionId);
        } finally {
          _executingActions.remove(actionId);
        }
      }
      return false;
    }

    final action = actionRegistry.getAction(actionId);
    if (action == null) {
      return false;
    }
    if (!action.isEnabled()) {
      return false;
    }
    _executingActions.add(actionId);
    try {
      action.execute({});
    } finally {
      _executingActions.remove(actionId);
    }
    return true;
  }

  /// Resolves a wildcard action ID like '*.deleteLine' by checking the
  /// action registry for actions with a matching suffix.
  bool _executeWildcardAction(String wildcardId) {
    final actionSuffix = wildcardId.substring(2); // Remove '*.'
    final activeEditor = systemState.activeEditor;

    if (activeEditor == null) {
      notifications.showInformation(
        'No active editor for action "$actionSuffix"',
      );
      return false;
    }

    // Find all registered actions that end with the same suffix.
    final candidates = actionRegistry.allActions
        .where((a) => a.id.endsWith('.$actionSuffix'))
        .toList();

    if (candidates.isEmpty) {
      notifications.showInformation(
        'No editor supports action "$actionSuffix"',
      );
      return false;
    }

    // If only one candidate, use it directly.
    if (candidates.length == 1) {
      final action = candidates.first;
      if (!action.isEnabled()) return false;
      action.execute({});
      return true;
    }

    // Multiple candidates — determine the active editor's prefix from its
    // URI extension (e.g. '.dart' → 'dart', '.md' → 'md', '.yaml' → 'yaml').
    final editorPrefix = _editorPrefixFromUri(activeEditor.uri);
    if (editorPrefix != null) {
      final resolvedId = '$editorPrefix.$actionSuffix';
      final action = actionRegistry.getAction(resolvedId);
      if (action != null) {
        if (!action.isEnabled()) return false;
        action.execute({});
        return true;
      }
    }

    // Fallback: check generic prefixes like 'edit' or 'editor'.
    for (final prefix in ['edit', 'editor']) {
      final resolvedId = '$prefix.$actionSuffix';
      final action = actionRegistry.getAction(resolvedId);
      if (action != null && action.isEnabled()) {
        action.execute({});
        return true;
      }
    }

    // Report that the active editor doesn't support this action.
    final editorTitle = activeEditor.title.value;
    notifications.showInformation(
      '$editorTitle doesn\'t support "$actionSuffix" action',
    );
    return false;
  }

  /// Maps a file URI extension to the editor action prefix.
  String? _editorPrefixFromUri(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.dart')) return 'dart';
    if (path.endsWith('.md') || path.endsWith('.markdown')) return 'md';
    if (path.endsWith('.yaml') || path.endsWith('.yml')) return 'yaml';
    if (path.endsWith('.txt')) return 'plaintext';
    // For unknown extensions, try to match by checking which prefixes have
    // actions registered in the registry.
    return null;
  }

  @override
  bool isActionEnabled(String actionId) {
    if (actionId.startsWith('*.')) {
      // Wildcard actions are enabled if any candidate exists.
      final suffix = actionId.substring(2);
      return actionRegistry.allActions.any(
        (a) => a.id.endsWith('.$suffix') && a.isEnabled(),
      );
    }
    // Route standard editing actions through the active editor.
    if (StandardEditingActions.standardActionIds.contains(actionId)) {
      final editor = systemState.activeEditor;
      return editor?.isActionEnabled(actionId) ?? false;
    }
    final action = actionRegistry.getAction(actionId);
    return action?.isEnabled() ?? false;
  }

  @override
  bool undo() => executeAction(StandardEditingActions.undoActionId);

  @override
  bool redo() => executeAction(StandardEditingActions.redoActionId);

  /// Opens [uri]: asks every module first ([ForgeModule.openUri]), then the
  /// [editorHost]; answers whether something opened it.
  @override
  Future<bool> openFile(Uri uri) async {
    for (final module in modules.allModules) {
      if (module.openUri(uri)) return true;
    }
    return await editorHost.openEditorFor(uri) != null;
  }

  @override
  List<ForgeAction> getContextActionsFor(String editorId) {
    return actionRegistry.allActions
        .where((action) => action.showInContextMenu)
        .where((action) => action.isVisible() && action.isEnabled())
        .toList(growable: false);
  }

  @override
  ForgeTextSettings getTextSettings(String editorTypeId) {
    return _editorTextSettings[editorTypeId] ?? const ForgeTextSettings();
  }

  @override
  void setTextSettings(String editorTypeId, ForgeTextSettings settings) {
    if (_editorTextSettings[editorTypeId] == settings) return;
    _editorTextSettings[editorTypeId] = settings;
    _textSettingsChanged.fire();
  }

  final _TextSettingsChanged _textSettingsChanged = _TextSettingsChanged();

  @override
  Listenable get textSettingsChanged => _textSettingsChanged;

  final Map<String, Map<String, dynamic>> _editorSpecificConfig =
      <String, Map<String, dynamic>>{};

  @override
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId) {
    return Map<String, dynamic>.from(
      _editorSpecificConfig[editorTypeId] ?? <String, dynamic>{},
    );
  }

  @override
  void setEditorSpecificConfig(
    String editorTypeId,
    Map<String, dynamic> config,
  ) {
    _editorSpecificConfig[editorTypeId] = Map<String, dynamic>.from(config);
  }

  @override
  Map<String, String> getFileTypeDefaults() {
    return Map<String, String>.unmodifiable(_fileTypeDefaults);
  }

  @override
  void setFileTypeDefault(String extension, String editorTypeId) {
    final normalized = _normalizeExtension(extension);
    _fileTypeDefaults[normalized] = editorTypeId;

    final layoutController = layout;
    if (layoutController is DefaultLayoutController) {
      layoutController.setFileTypeDefaultEditor(normalized, editorTypeId);
    }
  }

  @override
  void clearFileTypeDefault(String extension) {
    final normalized = _normalizeExtension(extension);
    _fileTypeDefaults.remove(normalized);

    final layoutController = layout;
    if (layoutController is DefaultLayoutController) {
      layoutController.clearFileTypeDefaultEditor(normalized);
    }
  }

  String _normalizeExtension(String extension) {
    final trimmed = extension.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed == '*') {
      return trimmed;
    }
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }

  /// Restores a file from a revision snapshot.
  ///
  /// Writes the revision content to the file system and re-opens the file
  /// in the editor. The replaced content is itself snapshotted as a revision
  /// before overwriting, enabling non-destructive restore.
  Future<bool> restoreFileFromRevision(Uri fileUri, String revisionId) async {
    if (!workspaceState.isInitialized) return false;
    final content = await workspaceState.readRevision(fileUri, revisionId);
    if (content == null) return false;

    // Snapshot current content before overwriting.
    try {
      final currentContent = await fileSystem.readText(fileUri);
      await workspaceState.createRevision(fileUri, currentContent);
    } catch (_) {
      // If we can't snapshot current content, proceed anyway.
    }

    await fileSystem.writeText(fileUri, content);
    await fileSystem.save(fileUri);

    // Refresh open editor if present.
    final existing = (systemState as DefaultSystemState).openEditors
        .where((e) => e.uri == fileUri)
        .firstOrNull;
    if (existing != null && !existing.replaceContent(content)) {
      _reopen(existing);
    }

    return true;
  }

  /// Closes [editor] and opens its file again in the panel it was in — for an
  /// editor that cannot take replaced content in place
  /// ([ForgeEditor.replaceContent] returned false), so it never stays on the
  /// old text with a history made against it.
  void _reopen(ForgeEditor editor) {
    final layout = this.layout;
    if (layout is! DefaultLayoutController) return;
    final panel = layout.middlePanels.value.indexWhere(
      (editors) => editors.contains(editor),
    );
    layout.closeEditor(editor);
    layout.openFile(editor.uri, middlePanelIndex: panel < 0 ? null : panel);
  }

  bool _savesApplications = false;
  Set<String> _savedApplicationIds = const {};

  /// The write in flight, and whether another change came in meanwhile:
  /// writes run one at a time and the last change is always written.
  Future<void>? _applicationsWrite;
  bool _applicationsChangedDuringWrite = false;
  final Set<String> _removedApplicationIds = {};

  /// Recreates the restorable applications that were open at the last exit
  /// (`.forge/state/applications.json`) through their factories, and from
  /// then on writes the file whenever the open applications change.
  ///
  /// Call once, after the modules are activated (they register their
  /// factories) and the workspace state is initialized. Nothing is written
  /// before this runs, so a start cannot overwrite the last exit's list with
  /// the static applications alone.
  Future<void> restoreApplications() async {
    if (!workspaceState.isInitialized || _savesApplications) return;
    final saved = await workspaceState.loadOpenApplications();
    if (saved != null) applications.restore(saved);
    _savesApplications = true;
    _savedApplicationIds = {for (final app in applications.all) app.id};
    applications.listenable.addListener(_saveApplications);
    _saveApplications();
  }

  /// Writes the open applications, and deletes the per-application state of
  /// any that was removed since the last write.
  void _saveApplications() {
    if (!workspaceState.isInitialized) return;
    final open = {for (final app in applications.all) app.id};
    _removedApplicationIds.addAll(_savedApplicationIds.difference(open));
    _savedApplicationIds = open;
    _writeApplications();
  }

  void _writeApplications() {
    if (_applicationsWrite != null) {
      _applicationsChangedDuringWrite = true;
      return;
    }
    _applicationsWrite = () async {
      do {
        _applicationsChangedDuringWrite = false;
        final removed = [..._removedApplicationIds];
        _removedApplicationIds.clear();
        try {
          await workspaceState.saveOpenApplications(applications.snapshot());
          for (final id in removed) {
            await workspaceState.deleteApplicationState(id);
          }
        } on Exception catch (e) {
          notifications.showWarning(
            'The open applications could not be saved for the next start: $e',
          );
        }
        // Disposing the shell disposes the workspace state: a change that
        // came in during the last write has nowhere to go any more.
      } while (_applicationsChangedDuringWrite && workspaceState.isInitialized);
      _applicationsWrite = null;
    }();
  }

  /// Completes when the open applications as they are now are on disk, and
  /// the per-application state of the removed ones is deleted.
  Future<void> applicationsWritten() async {
    while (_applicationsWrite != null) {
      await _applicationsWrite;
    }
  }

  /// Disposes all services that own resources.
  ///
  /// Sequence: deactivate modules (reverse order), then dispose layout
  /// and system state. Called from the scaffold's shutdown flow.
  void dispose() {
    applications.listenable.removeListener(_bindActiveContributions);
    if (_savesApplications) {
      applications.listenable.removeListener(_saveApplications);
    }
    final registry = modules;
    if (registry is DefaultModuleRegistry) {
      registry.deactivateAll();
    }
    workspaceState.dispose();
    final history = navigationHistory;
    if (history is DefaultNavigationHistory) history.dispose();
    final layoutCtrl = layout;
    if (layoutCtrl is DefaultLayoutController) {
      layoutCtrl.dispose();
    }
    final state = systemState;
    if (state is DefaultSystemState) {
      state.shutdown();
      state.dispose();
    }
    final diag = diagnostics;
    if (diag is DefaultDiagnosticManager) {
      diag.dispose();
    }
    final notif = notifications;
    if (notif is DefaultNotificationManager) {
      notif.dispose();
    }
  }
}

class _TextSettingsChanged extends ChangeNotifier {
  void fire() => notifyListeners();
}

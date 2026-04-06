import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings;

import '../model/forge_config.dart';
import '../actions/forge_action.dart';
import '../services/forge_action_registry.dart';
import '../services/forge_clipboard.dart';
import '../services/forge_config_manager.dart';
import '../services/forge_dialog_manager.dart';
import '../services/forge_diagnostic_manager.dart';
import '../services/forge_environment.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_file_system.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_notification_manager.dart';
import '../services/forge_outline_manager.dart';
import '../services/forge_output_channel_manager.dart';
import '../services/forge_progress_manager.dart';
import '../services/forge_search_manager.dart';
import '../services/forge_secret_storage.dart';
import '../services/forge_shortcut_manager.dart';
import '../services/forge_terminal_manager.dart';
import '../services/forge_undo_manager.dart';
import '../services/forge_virtual_document_manager.dart';
import '../services/forge_workspace_state_manager.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_module_registry.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_status_bar_controller.dart';
import '../shell/forge_system_state.dart';
import 'default_clipboard.dart';
import 'default_action_registry.dart';
import 'default_config_manager.dart';
import 'default_diagnostic_manager.dart';
import 'default_dialog_manager.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultExecutionMonitor, ForgeExecutionMonitor;
import 'default_layout_controller.dart';
import 'default_module_registry.dart';
import 'default_notification_manager.dart';
import 'default_outline_manager.dart';
import 'default_output_manager.dart';
import 'default_progress_manager.dart';
import 'default_search_manager.dart';
import 'default_status_bar_controller.dart';
import 'default_system_state.dart';
import 'default_undo_manager.dart';
import 'default_workspace_state_manager.dart';
import 'memory_file_system.dart';
import 'platform_secret_storage.dart';
import 'pty_terminal.dart';
import 'real_file_system.dart';
import 'real_search_manager.dart';
import 'stub_services.dart';

/// Default implementation of [ForgeShellApi].
///
/// Aggregates all default service implementations and provides them
/// as a single API surface for module activation.
class DefaultShellApi implements ForgeShellApi {
  @override
  final ForgeSystemState systemState;

  @override
  final ForgeLayoutController layout;

  @override
  final ForgeStatusBarController statusBar;

  @override
  final ForgeFileSystem fileSystem;

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

  final Map<String, ForgeTextSettings> _editorTextSettings = {};
  final Map<String, String> _fileTypeDefaults = {};

  DefaultShellApi({
    required this.systemState,
    required this.layout,
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
  }) : workspaceState = workspaceState ?? DefaultWorkspaceStateManager();

  /// Creates a [DefaultShellApi] with all default implementations wired.
  ///
  /// [fileSystemSeed] populates the in-memory file system.
  /// [appName] is used as the application config name.
  /// [navigatorKey] enables dialog routing.
  factory DefaultShellApi.withDefaults({
    required Map<String, String> fileSystemSeed,
    required String appName,
    required GlobalKey<NavigatorState> navigatorKey,
    ForgeConfig initialConfig = const ForgeConfig(),
  }) {
    final memFs = MemoryFileSystem(seed: fileSystemSeed);
    return DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: memFs,
      appName: appName,
      navigatorKey: navigatorKey,
      initialConfig: initialConfig,
    );
  }

  /// Creates a [DefaultShellApi] with a custom [ForgeFileSystem].
  ///
  /// Use this factory when you need a real file system or custom implementation.
  /// [fileSystem] is the file system to use.
  /// [appName] is used as the application config name.
  /// [navigatorKey] enables dialog routing.
  factory DefaultShellApi.withDefaultsAndFileSystem({
    required ForgeFileSystem fileSystem,
    required String appName,
    required GlobalKey<NavigatorState> navigatorKey,
    ForgeWorkspaceStateManager? workspaceState,
    ForgeModuleStorage? storage,
    ForgeConfig initialConfig = const ForgeConfig(),
  }) {
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
    );
    final statusBarController = DefaultStatusBarController(
      registry: moduleRegistry,
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

    final progressManager = DefaultProgressManager();
    final dialogManager = DefaultDialogManager();
    final undoManager = DefaultUndoManager();
    final clipboardService = DefaultClipboard();

    // Choose search manager based on file system type
    ForgeSearchManager searchManager;
    if (fileSystem is MemoryFileSystem) {
      searchManager = DefaultSearchManager(fileSystem: fileSystem);
    } else if (fileSystem is RealFileSystem) {
      searchManager = RealSearchManager(
        rootDirectory: fileSystem.rootDirectory,
      );
    } else {
      // Fallback: create an empty MemoryFileSystem for search
      searchManager = DefaultSearchManager(
        fileSystem: MemoryFileSystem(seed: {}),
      );
    }

    final outlineManager = DefaultOutlineManager();
    // Use PTY-backed terminals on desktop (RealFileSystem), fallback for tests.
    final ForgeTerminalManager terminalManager =
        fileSystem is RealFileSystem
            ? PtyTerminalManager()
            : DefaultTerminalManager();
    final storageService = storage ?? DefaultModuleStorage();
    final environmentService = DefaultEnvironment();
    final executionMonitor = DefaultExecutionMonitor();
    // Use platform keychain on desktop, in-memory for tests.
    final ForgeSecretStorage secretStorage =
        fileSystem is RealFileSystem
            ? PlatformSecretStorage()
            : DefaultSecretStorage();
    final fileDecorationManager = DefaultFileDecorationManager();

    // Auto-bridge: sync diagnostics from manager into system state so
    // status-bar items, event streams, and summary counters stay current.
    diagnosticManager.allNotifier.addListener(() {
      systemState.setDiagnostics(diagnosticManager.allNotifier.value);
    });

    return DefaultShellApi(
      systemState: systemState,
      layout: layoutController,
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
    );
  }

  @override
  bool executeAction(String actionId) {
    // Handle wildcard action IDs (e.g. '*.deleteLine').
    if (actionId.startsWith('*.')) {
      return _executeWildcardAction(actionId);
    }

    final action = actionRegistry.getAction(actionId);
    if (action == null) {
      return false;
    }
    if (!action.isEnabled()) {
      return false;
    }
    action.execute({});
    return true;
  }

  /// Resolves a wildcard action ID like '*.deleteLine' by checking the
  /// active editor's registered actions for a matching suffix.
  bool _executeWildcardAction(String wildcardId) {
    final actionSuffix = wildcardId.substring(2); // Remove '*.'
    final activeEditor = systemState.activeEditor;

    if (activeEditor == null) {
      notifications.showInformation(
        'No active editor for action "$actionSuffix"',
      );
      return false;
    }

    // Try to find the action by scanning all registered actions for ones
    // that end with the same suffix and have a prefix matching the active
    // editor's action namespace.
    final candidates = actionRegistry.allActions
        .where((a) => a.id.endsWith('.$actionSuffix'))
        .toList();

    if (candidates.isEmpty) {
      notifications.showInformation(
        'No editor supports action "$actionSuffix"',
      );
      return false;
    }

    // Determine the active editor's prefix by looking at its registered
    // actions: e.g. if it registers 'dart.toggleComment', prefix is 'dart'.
    final editorActions = activeEditor.actions;
    final editorPrefixes = <String>{};
    for (final action in editorActions) {
      final dotIdx = action.id.indexOf('.');
      if (dotIdx > 0) {
        editorPrefixes.add(action.id.substring(0, dotIdx));
      }
    }

    // Try each editor prefix to find a matching candidate.
    for (final prefix in editorPrefixes) {
      final resolvedId = '$prefix.$actionSuffix';
      final action = actionRegistry.getAction(resolvedId);
      if (action != null) {
        if (!action.isEnabled()) {
          return false;
        }
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

  @override
  bool isActionEnabled(String actionId) {
    if (actionId.startsWith('*.')) {
      // Wildcard actions are enabled if any candidate exists.
      final suffix = actionId.substring(2);
      return actionRegistry.allActions
          .any((a) => a.id.endsWith('.$suffix') && a.isEnabled());
    }
    final action = actionRegistry.getAction(actionId);
    return action?.isEnabled() ?? false;
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
    _editorTextSettings[editorTypeId] = settings;
  }

  final Map<String, Map<String, dynamic>> _editorSpecificConfig =
      <String, Map<String, dynamic>>{};

  @override
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId) {
    return Map<String, dynamic>.from(
        _editorSpecificConfig[editorTypeId] ?? <String, dynamic>{});
  }

  @override
  void setEditorSpecificConfig(
      String editorTypeId, Map<String, dynamic> config) {
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

  String _normalizeExtension(String extension) {
    final trimmed = extension.trim().toLowerCase();
    if (trimmed.isEmpty) {
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
      final currentContent = await fileSystem.read(fileUri);
      await workspaceState.createRevision(fileUri, currentContent);
    } catch (_) {
      // If we can't snapshot current content, proceed anyway.
    }

    await fileSystem.write(fileUri, content);
    await fileSystem.save(fileUri);

    // Refresh open editor if present.
    final existing = (systemState as DefaultSystemState).openEditors
        .where((e) => e.uri == fileUri)
        .firstOrNull;
    if (existing != null) {
      existing.setContent(content);
      existing.markClean();
    }

    return true;
  }

  /// Disposes all services that own resources.
  ///
  /// Sequence: deactivate modules (reverse order), then dispose layout
  /// and system state. Called from the scaffold's shutdown flow.
  void dispose() {
    final registry = modules;
    if (registry is DefaultModuleRegistry) {
      registry.deactivateAll();
    }
    workspaceState.dispose();
    final layoutCtrl = layout;
    if (layoutCtrl is DefaultLayoutController) {
      layoutCtrl.dispose();
    }
    final state = systemState;
    if (state is DefaultSystemState) {
      state.dispose();
    }
    final diag = diagnostics;
    if (diag is DefaultDiagnosticManager) {
      diag.dispose();
    }
  }
}
